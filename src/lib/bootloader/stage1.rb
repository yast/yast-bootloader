require "forwardable"

require "yast"
require "bootloader/udev_mapping"
require "bootloader/bootloader_factory"
require "bootloader/stage1_device"
require "bootloader/stage1_proposal"
require "cfa/grub2/install_device"
require "y2storage"

Yast.import "Arch"
Yast.import "BootStorage"

module Bootloader
  # Represents where is bootloader stage1 installed. Allows also proposing its
  # location.
  class Stage1
    extend Forwardable
    include Yast::Logger

    attr_reader :model
    def_delegators :@model, :generic_mbr?, :generic_mbr=, :activate?, :activate=, :devices,
      :add_device

    def initialize
      @model = CFA::Grub2::InstallDevice.new
    end

    def inspect
      "<Bootloader::Stage1 #{object_id} activate: #{activate?} " \
        "generic_mbr: #{generic_mbr?} devices: #{devices.inspect}>"
    end

    def read
      @model.load
    end

    def write
      @model.save
    end

    # Checks if given device is used as stage1 location
    # @param [String] dev device to check, it can be kernel or udev name,
    #   it can also be virtual or real device, method convert it as needed
    def include?(dev)
      kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)
      real_devs = ::Bootloader::Stage1Device.new(kernel_dev).real_devices

      include_real_devs?(real_devs)
    end

    def add_udev_device(dev)
      kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)
      real_devices = ::Bootloader::Stage1Device.new(kernel_dev).real_devices
      udev_devices = real_devices.map { |d| Bootloader::UdevMapping.to_mountby_device(d) }
      udev_devices.each { |d| @model.add_device(d) }
    end

    def remove_device(dev)
      kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

      dev = devices.find do |map_dev|
        kernel_dev == Bootloader::UdevMapping.to_kernel_device(map_dev)
      end

      @model.remove_device(dev)
    end

    def clear_devices
      devices.each do |dev|
        @model.remove_device(dev)
      end
    end

    def boot_partition?
      if !@boot_partition_device
        dev = Yast::BootStorage.BootPartitionDevice
        kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

        @boot_partition_device = ::Bootloader::Stage1Device.new(kernel_dev)
      end

      include_real_devs?(@boot_partition_device.real_devices)
    end

    def root_partition?
      if !@root_partition_device
        dev = Yast::BootStorage.RootPartitionDevice
        kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

        @root_partition_device = ::Bootloader::Stage1Device.new(kernel_dev)
      end

      include_real_devs?(@root_partition_device.real_devices)
    end

    def mbr?
      if !@mbr_device
        dev = Yast::BootStorage.mbr_disk
        kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

        @mbr_device = ::Bootloader::Stage1Device.new(kernel_dev)
      end

      include_real_devs?(@mbr_device.real_devices)
    end

    def extended_partition?
      return false unless Yast::BootStorage.ExtendedPartitionDevice

      if !@extended_partition_device
        dev = Yast::BootStorage.ExtendedPartitionDevice
        kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

        @extended_partition_device = ::Bootloader::Stage1Device.new(kernel_dev)
      end

      include_real_devs?(@extended_partition_device.real_devices)
    end

    def custom_devices
      known_devices = [
        Yast::BootStorage.BootPartitionDevice,
        Yast::BootStorage.RootPartitionDevice,
        Yast::BootStorage.mbr_disk,
        Yast::BootStorage.ExtendedPartitionDevice
      ]
      known_devices.compact!
      known_devices.map! { |d| Bootloader::UdevMapping.to_kernel_device(d) }

      devices.select do |dev|
        !known_devices.include?(Bootloader::UdevMapping.to_kernel_device(dev))
      end
    end

    # Propose and set Stage1 location.
    # It sets properly all devices where bootloader stage1 should be written.
    # It also sets if partition should be activated by setting its boot flag.
    # It proposes if generic_mbr will be written into MBR.
    # The proposal is only based on storage information, disregarding any
    # existing values of the output variables (which are respected at other times, in AutoYaST).
    def propose
      Stage1Proposal.propose(self)
    end

    # returns hash, where key is symbol for location and value is device name
    def available_locations
      case Yast::Arch.architecture
      when "i386", "x86_64"
        res = available_partitions
        res[:mbr] = Yast::BootStorage.mbr_disk

        return res
      else
        log.info "no available non-custom location for arch #{Yast::Arch.architecture}"

        return {}
      end
    end

    def can_use_boot?
      partition = Yast::BootStorage.BootPartitionDevice

      part = partitions.find { |p| p.name == partition }

      if !part
        log.error "cannot find partition #{partition}"
        return false
      end

      log.info "Boot partition info #{part.inspect}"

      # cannot install stage one to xfs as it doesn't have reserved space (bnc#884255)
      return false if part.filesystem_type == ::Y2Storage::Filesystems::Type::XFS

      # LVM partition does not have reserved space for stage one
      return false if partition.descendants.any? { |d| d.is?(:lvm_vg) }

      true
    end

    def merge(other)
      # merge here is a bit tricky, as for stage1 does not exist `defined?`
      # because grub_installdevice contain value or not, so it is not
      # possible to recognize if chosen or just not set
      # so logic is following
      # 1) if any flag is set to true, then use it because e.g. autoyast defined flags,
      #    but devices usually not
      # 2) if there is devices specified, then set also flags to value in other
      #    as it mean, that there is enough info to decide
      log.info "stage1 to merge #{other.inspect}"

      if other.devices.empty?
        self.activate    = activate? || other.activate?
        self.generic_mbr = generic_mbr? || other.generic_mbr?
      else
        clear_devices
        other.devices.each { |d| add_udev_device(d) }

        self.activate    = other.activate?
        self.generic_mbr = other.generic_mbr?
      end

      log.info "stage1 after merge #{inspect}"
    end

  private

    # Partitions in the staging (planned) devicegraph
    #
    # @return [Y2Storage::PartitionsList]
    def partitions
      staging.partitions
    end

    def staging
      Y2Storage::StorageManager.instance.y2storage_staging
    end

    def include_real_devs?(real_devs)
      real_devs.all? do |real_dev|
        devices.any? do |map_dev|
          real_dev == Bootloader::UdevMapping.to_kernel_device(map_dev)
        end
      end
    end

    def available_partitions
      return {} unless can_use_boot?

      res = {}
      if Yast::BootStorage.separated_boot?
        res[:boot] = Yast::BootStorage.BootPartitionDevice
      else
        res[:root] = Yast::BootStorage.RootPartitionDevice
      end

      if extended_partition?
        res[:extended] = Yast::BootStorage.ExtendedPartitionDevice
      end

      res
    end
  end
end
