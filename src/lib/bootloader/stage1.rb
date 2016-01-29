require "yast"
require "bootloader/udev_mapping"
require "bootloader/bootloader_factory"
require "cfa/grub2/install_device"

module Bootloader
  # Represents where is bootloader stage1 installed. Allows also proposing its
  # location.
  class Stage1
    include Yast::Logger
    attr_reader :model

    def initialize
      Yast.import "Arch"
      Yast.import "BootStorage"
      Yast.import "Kernel"
      Yast.import "Storage"

      @model = CFA::Grub2::InstallDevice.new
    end

    def read
      @model.load
    end

    def write
      @model.save
    end

    def include?(dev)
      kernel_dev = Bootloader::UdevMapping.to_kernel_device(dev)

      @model.devices.any? do |map_dev|
        kernel_dev == Bootloader::UdevMapping.to_kernel_device(map_dev)
      end
    end

    def add_udev_device(dev)
      udev_device = Bootloader::UdevMapping.to_mountby_device(dev)
      @model.add_device(udev_device)
    end

    def clear_devices
      @model.devices.each do |dev|
        @model.remove_device(dev)
      end
    end

    def boot_partition?
      include?(Yast::BootStorage.BootPartitionDevice)
    end

    def root_partition?
      include?(Yast::BootStorage.RootPartitionDevice)
    end

    def mbr?
      include?(Yast::BootStorage.mbr_disk)
    end

    def extended?
      include?(Yast::BootStorage.ExtendedPartitionDevice)
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

      @model.devices.select do |dev|
        !known_devices.include?(Bootloader::UdevMapping.to_kernel_device(dev))
      end
    end

    # Propose and set Stage1 location.
    # It sets properly all "boot_*" entries in globals. It also sets if partition
    # should be activated by setting its boot flag (in globals key "activate").
    # It proposes if generic_mbr will be written into MBR (globals key "generic_mbr").
    # And last but not least it propose if protective MBR flag need to be removed
    # The proposal is only based on storage information, disregarding any
    # existing values of the output variables (which are respected at other times, in AutoYaST).
    # @see for keys in globals to https://old-en.opensuse.org/YaST/Bootloader_API#global_options_in_map
    def propose
      case Yast::Arch.architecture
      when "i386", "x86_64"
        propose_x86
      when /ppc/
        propose_ppc
      when /s390/
        propose_s390
      else
        raise "unsuported architecture #{Yast::Arch.architecture}"
      end
    end

    # returns hash, where key is symbol for location and value is device name
    def available_locations
      res = {}

      case Yast::Arch.architecture
      when "i386", "x86_64"
        available_partitions(res)
        res[:mbr] = Yast::BootStorage.mbr_disk
      else
        log.info "no available non-custom location for arch #{Yast::Arch.architecture}"
      end

      res
    end

  private

    def available_partitions(res)
      return unless Yast::BootStorage.can_boot_from_partition

      if Yast::BootStorage.BootPartitionDevice != Yast::BootStorage.RootPartitionDevice
        res[:boot] = Yast::BootStorage.BootPartitionDevice
      else
        res[:root] = Yast::BootStorage.RootPartitionDevice
      end
      res[:extended] = extended if logical_boot?
    end

    def propose_x86
      selected_location = propose_boot_location
      log.info "propose_x86 (#{selected_location}"

      # set active flag, if needed
      if selected_location == :mbr &&
          underlying_boot_partition_devices.size <= 1
        # We are installing into MBR:
        # If there is an active partition, then we do not need to activate
        # one (otherwise we do).
        # Reason: if we use our own MBR code, we do not rely on the activate
        # flag in the partition table to boot Linux. Thus, the activated
        # partition can remain activated, which causes less problems with
        # other installed OSes like Windows (older versions assign the C:
        # drive letter to the activated partition).
        boot_flag_part = Yast::Storage.GetBootPartition(Yast::BootStorage.mbr_disk)
        @model.activate = boot_flag_part.empty?
      else
        # if not installing to MBR, always activate (so the generic MBR will
        # boot Linux)
        @model.activate = true
        @model.generic_mbr = true
      end
    end

    def propose_s390
      # s390 do not need any partition as it is stored to predefined zipl location
      assign_bootloader_device(:none)
    end

    def propose_ppc
      partition = Yast::BootStorage.prep_partitions.first
      if partition
        assign_bootloader_device([:custom, partition])
      # handle diskless setup, in such case do not write boot code anywhere (bnc#874466)
      # we need to detect what is mount on /boot and if it is nfs, then just
      # skip this proposal. In other case if it is not nfs, then it is error and raise exception
      elsif Yast::BootStorage.disk_with_boot_partition == "/dev/nfs"
        return
      else
        raise "there is no prep partition"
      end
    end

    def propose_boot_location
      raise "Boot partition disk not found" if boot_partition_disk.empty?
      selected_location = :mbr
      separate_boot = Yast::BootStorage.BootPartitionDevice != Yast::BootStorage.RootPartitionDevice

      # there was check if boot device is on logical partition
      # IMO it is good idea check MBR also in this case
      # see bug #279837 comment #53
      if boot_partition_on_mbr_disk?
        selected_location = separate_boot ? :boot : :root
      elsif underlying_boot_partition_devices.size > 1
        selected_location = :mbr
      end

      if logical_boot? && extended_partition
        log.info "/boot is on logical partition and extended detected, extended proposed"
        selected_location = :extended
      end

      if boot_with_btrfs? && logical_boot?
        log.info "/boot is on logical partition and uses btrfs, mbr is favored in this situation"
        selected_location = :mbr
      end

      # for separate btrfs partition prefer MBR (bnc#940797)
      if boot_with_btrfs? && separate_boot
        log.info "separated /boot is used and uses btrfs, mbr is favored in this situation"
        selected_location = :mbr
      end

      if !Yast::BootStorage.can_boot_from_partition
        log.info "/boot cannot be used to install stage1"
        selected_location = :mbr
      end

      assign_bootloader_device(selected_location)
    end

    def extended_partition
      init_boot_info unless @boot_initialized

      @extended
    end

    def logical_boot?
      init_boot_info unless @boot_initialized

      @logical_boot
    end

    def boot_with_btrfs?
      init_boot_info unless @boot_initialized

      @boot_with_btrfs
    end

    def init_boot_info
      return if @boot_initialized

      @boot_initialized = true
      boot_disk_map = target_map[boot_partition_disk] || {}
      partitions_on_boot_partition_disk = boot_disk_map["partitions"] || []
      @logical_boot = false
      @boot_with_btrfs = false

      partitions_on_boot_partition_disk.each do |p|
        if p["type"] == :extended
          @extended = p["device"]
        elsif underlying_boot_partition_devices.include?(p["device"])
          @boot_with_btrfs = true if p["used_fs"] == :btrfs
          @logical_boot = true if p["type"] == :logical
        end
      end

      log.info "/boot is in logical partition: #{@logical_boot}"
      log.info "/boot use btrfs: #{@boot_with_btrfs}"
      log.info "The extended partition: #{@extended}"
    end

    # Set "boot_*" flags in the globals map according to the boot device selected
    # with parameter selected_location. Only a single boot device can be selected
    # with this function. The function cannot be used to set a custom boot device.
    # It will always be deleted.
    #
    # FIXME: `mbr_md is probably unneeded; AFA we can see, this decision is
    # automatic anyway and perl-Bootloader should be able to make it without help
    # from the user or the proposal.
    #
    # @param [Symbol, Array] selected_location symbol one of :boot, :root, :mbr,
    #   :extended, `none or Array with first value :custom and second device for
    #   custom devices
    def assign_bootloader_device(selected_location)
      log.info "assign bootloader device '#{selected_location.inspect}'"
      # first, default to all off:
      @model.devices.each { |d| @model.remove_device(d) }

      case selected_location
      when :root then add_udev_device(Yast::BootStorage.RootPartitionDevice)
      when :boot then add_udev_device(Yast::BootStorage.BootPartitionDevice)
      when :extended then add_udev_device(extended)
      when :mbr
        add_udev_device(Yast::BootStorage.mbr_disk)
        # Disable generic MBR as we want grub2 there
        @model.generic_mbr = true
      when :none
        log.info "Resetting bootloader device"
      when Array
        if selected_location.first != :custom
          raise "Unknown value to select bootloader device #{selected_location.inspect}"
        end

        @model.add_device(selected_location[1]) # add directly proposed value without changes
      else
        raise "Unknown value to select bootloader device #{selected_location.inspect}"
      end
    end

    def target_map
      @target_map ||= Yast::Storage.GetTargetMap
    end

    def boot_partition_disk
      Yast::BootStorage.disk_with_boot_partition
    end

    # determine the underlying devices for the "/boot" partition (either the
    # BootPartitionDevice, or the devices from which the soft-RAID device for
    # "/boot" is built)
    def underlying_boot_partition_devices
      underlying_boot_partition_devices = [Yast::BootStorage.BootPartitionDevice]
      md_info = Yast::BootStorage.Md2Partitions(Yast::BootStorage.BootPartitionDevice)
      underlying_boot_partition_devices = md_info.keys if !md_info.empty?
      log.info "Boot partition devices: #{underlying_boot_partition_devices}"

      underlying_boot_partition_devices
    end

    def boot_partition_on_mbr_disk?
      boot_partition_on_mbr_disk = underlying_boot_partition_devices.any? do |dev|
        pdp = Yast::Storage.GetDiskPartition(dev)
        p_disk = pdp["disk"] || ""
        p_disk == Yast::BootStorage.mbr_disk
      end

      log.info "/boot is on 1st disk: #{boot_partition_on_mbr_disk}"

      boot_partition_on_mbr_disk
    end
  end
end
