require "forwardable"

require "yast"
require "bootloader/udev_mapping"
require "bootloader/bootloader_factory"
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
      real_devs = Yast::BootStorage.stage1_device_for_name(kernel_dev)
      real_devs_names = real_devs.map(&:name)

      include_real_devs?(real_devs_names)
    end

    # Adds to devices udev variant for given device.
    # @param dev [String] device to add. Can be also logical device that is translated to
    #   physical one. If specific string should be added as it is then use #add_device
    def add_udev_device(dev)
      kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)
      real_devices = Yast::BootStorage.stage1_device_for_name(kernel_dev)
      udev_devices = real_devices.map { |d| Bootloader::UdevMapping.to_mountby_device(d.name) }
      udev_devices.each { |d| @model.add_device(d) }
    end

    # List of symbolic links of available locations to install. Possible values are
    # `:mbr` for disks and `:boot` for partitions.
    def available_locations
      case Yast::Arch.architecture
      when "i386", "x86_64"
        res = [:mbr]
        res << :boot if can_use_boot?
        return res
      else
        log.info "no available non-custom location for arch #{Yast::Arch.architecture}"

        return []
      end
    end

    # Removes device from list of stage 1 placements.
    # @param dev [String] device to remove, have to be always physical device,
    #   but can match different udev names.
    def remove_device(dev)
      kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

      dev = devices.find do |map_dev|
        kernel_dev == Bootloader::UdevMapping.to_kernel_device(map_dev)
      end

      @model.remove_device(dev)
    end

    # Removes all stage1 placements
    def clear_devices
      devices.each do |dev|
        @model.remove_device(dev)
      end
    end

    # partition names where stage1 can be placed and where /boot lives
    # @return [Array<String>]
    def boot_partition_names
      detect_devices

      @boot_devices
    end

    def boot_disk_names
      detect_devices

      @mbr_devices
    end

    def boot_partition?
      include_real_devs?(boot_partition_names)
    end

    def mbr?
      include_real_devs?(boot_disk_names)
    end

    def custom_devices
      known_devices = boot_disk_names + boot_partition_names
      log.info "known devices #{known_devices.inspect}"

      devices.select do |dev|
        kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)
        stage1_for_dev = Yast::BootStorage.stage1_device_for_name(kernel_dev).map(&:name)
        log.info "stage1 devices for #{dev} as #{kernel_dev} is #{stage1_for_dev.inspect}"
        # devices already covered by known devices by mbr or by partition
        !(stage1_for_dev - known_devices).empty?
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

    def can_use_boot?
      fs = Yast::BootStorage.boot_mountpoint

      # no boot assigned
      return false unless fs

      return false unless fs.is?(:blk_filesystem)

      # cannot install stage one to xfs as it doesn't have reserved space (bnc#884255)
      return false if fs.type == ::Y2Storage::Filesystems::Type::XFS

      parts = fs.blk_devices

      subgraph = parts.each_with_object([]) do |part, result|
        result.concat([part] + part.descendants + part.ancestors)
      end

      return false if subgraph.any? do |dev|
        # LVM partition does not have reserved space for stage one
        next true if dev.is?(:lvm_pv)
        # MD Raid does not have reserved space for stage one (bsc#1063957)
        next true if dev.is?(:md)
        # encrypted partition does not have reserved space and it is bad idea in general
        # (bsc#1056862)
        next true if dev.is?(:encryption)

        false
      end

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

    def staging
      Y2Storage::StorageManager.instance.staging
    end

    def include_real_devs?(real_devs)
      real_devs.all? do |real_dev|
        devices.any? do |map_dev|
          real_dev == Bootloader::UdevMapping.to_kernel_device(map_dev)
        end
      end
    end

    def detect_devices
      # check if cache is valid
      return if @cache_revision == Y2Storage::StorageManager.instance.staging_revision

      devices = Yast::BootStorage.boot_partitions
      @boot_devices = devices.map(&:name)

      devices = Yast::BootStorage.boot_disks
      @mbr_devices = devices.map(&:name)

      @cache_revision = Y2Storage::StorageManager.instance.staging_revision
    end
  end
end
