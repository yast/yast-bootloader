require "yast"

module Bootloader
  # Represents where is bootloader stage1 installed. Allows also proposing its
  # location.
  # @note it should replace all BootCommon.globals["boot_*"] and also "activate"
  #   and "generic_mbr" which is related to stage1 code
  class Stage1
    include Yast::Logger

    def initialize
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Storage"
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
      selected_location = propose_boot_location
      log.info "grub_ConfigureLocation (#{selected_location} on #{Yast::BootCommon.GetBootloaderDevices})"

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
        boot_flag_part = Yast::Storage.GetBootPartition(Yast::BootCommon.mbrDisk)
        Yast::BootCommon.globals["activate"] = boot_flag_part.empty? ? "true" : "false"
      else
        # if not installing to MBR, always activate (so the generic MBR will
        # boot Linux)
        Yast::BootCommon.globals["activate"] = "true"
        Yast::BootCommon.globals["generic_mbr"] = "true"
      end
      Yast::BootCommon.activate_changed = true

      # for GPT remove protective MBR flag otherwise some systems won't boot
      if gpt_boot_disk?
        Yast::BootCommon.pmbr_action = :remove
      end

      log.info "location configured. Resulting globals #{Yast::BootCommon.globals}"

      selected_location
    end

  private

    def propose_boot_location
      raise "Boot partition disk not found" if boot_partition_disk.empty?
      selected_location = :mbr

      # there was check if boot device is on logical partition
      # IMO it is good idea check MBR also in this case
      # see bug #279837 comment #53
      if boot_partition_on_mbr_disk?
        separate_boot = Yast::BootStorage.BootPartitionDevice != Yast::BootStorage.RootPartitionDevice
        selected_location =  separate_boot ? :boot : :root
      elsif underlying_boot_partition_devices.size > 1
        selected_location = :mbr
      end

      if logical_boot? && extended_partition &&
          underlying_boot_partition_devices.size > 1
        selected_location = :extended
      end

      if logical_boot_with_btrfs?
        log.info "/boot is on logical parititon and uses btrfs, mbr is favored in this situration"
        selected_location = :mbr
      end

      if !Yast::BootStorage.can_boot_from_partition
        log.info "/boot cannot be used to install stage1"
        selected_location = :mbr
      end

      assign_bootloader_device(selected_location)
      valid_locations = Yast::BootStorage.possible_locations_for_stage1
      if !valid_locations.include?(Yast::BootCommon.GetBootloaderDevices.first)
        selected_location = :mbr # default to mbr
        assign_bootloader_device(selected_location)
      end

      selected_location
    end

    def extended_partition
      init_boot_info unless @boot_initialized

      @extended
    end

    def logical_boot?
      init_boot_info unless @boot_initialized

      @logical_boot
    end

    def logical_boot_with_btrfs?
      init_boot_info unless @boot_initialized

      @logical_boot_with_btrfs
    end

    def init_boot_info
      boot_disk_map = target_map[boot_partition_disk] || {}
      partitions_on_boot_partition_disk = boot_disk_map["partitions"] || []
      @logical_boot = false
      @logical_boot_with_btrfs = false

      partitions_on_boot_partition_disk.each do |p|
        if p["type"] == :extended
          @extended = p["device"]
        elsif underlying_boot_partition_devices.include?(p["device"]) &&
            p["type"] == :logical
          # If any of the underlying_boot_partition_devices can be found on
          # the boot_partition_disk AND is a logical partition, set
          # is_logical to true.
          # For soft-RAID this will not match anyway ("/dev/[hs]da*" does not
          # match "/dev/md*").
          @logical_boot = true
          @logical_boot_with_btrfs = true if p["used_fs"] == :btrfs
        end
      end

      log.info "/boot is in logical partition: #{@logical_boot}"
      log.info "/boot is in logical partition and use btrfs: #{@logical_boot_with_btrfs}"
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
    # @param [Symbol] selected_location symbol one of `boot `root `mbr `extended `mbr_md `none
    def assign_bootloader_device(selected_location)
      # first, default to all off:
      ["boot_boot", "boot_root", "boot_mbr", "boot_extended"].each do |flag|
        Yast::BootCommon.globals[flag] = "false"
      end
      # need to remove the boot_custom key to switch this value off
      Yast::BootCommon.globals.delete("boot_custom")

      case selected_location
      when :root then Yast::BootCommon.globals["boot_root"] = "true"
      when :boot then Yast::BootCommon.globals["boot_boot"] = "true"
      when :extended then Yast::BootCommon.globals["boot_extended"] = "true"
      when :mbr
        Yast::BootCommon.globals["boot_mbr"] = "true"
        # Disable generic MBR as we want grub2 there
        Yast::BootCommon.globals["generic_mbr"] = "false"
      when :none
        log.info "Resetting bootloader device"
      else
        raise "Unknown value to select bootloader device #{selected_location.inspect}"
      end
    end

    # FIXME: find better location
    def gpt_boot_disk?
      targets = Yast::BootCommon.GetBootloaderDevices
      boot_discs = targets.map {|d| Yast::Storage.GetDisk(target_map, d)}
      boot_discs.any? {|d| d["label"] == "gpt" }
    end

    def target_map
      @target_map ||= Yast::Storage.GetTargetMap
    end

    def boot_partition_disk
      return @boot_partition_disk if @boot_partition_disk

      boot_device = Yast::BootStorage.BootPartitionDevice
      dp = Yast::Storage.GetDiskPartition(boot_device)
      @boot_partition_disk = dp["disk"] || ""
      return @boot_partition_disk if @boot_partition_disk.empty?

      partitions = target_map[@boot_partition_disk]["partitions"]
      boot_part = partitions.find { |p| p["device"] == boot_device }
      return @boot_partition_disk if boot_part["fstype"] != "md raid" # we are intersted only in raids

      result = boot_part["devices"].first
      result = Storage.GetDiskPartition(result)["disk"]

      log.info "Device for analyse MBR from soft-raid (MD-Raid only): #{result}"
      @boot_partition_disk = result
    end

    # determine the underlying devices for the "/boot" partition (either the
    # BootPartitionDevice, or the devices from which the soft-RAID device for
    # "/boot" is built)
    def underlying_boot_partition_devices
      return @underlying_boot_partition_devices if @underlying_boot_partition_devices

      @underlying_boot_partition_devices = [Yast::BootStorage.BootPartitionDevice]
      md_info = Yast::BootStorage.Md2Partitions(Yast::BootStorage.BootPartitionDevice)
      if !md_info.empty?
        @underlying_boot_partition_devices = md_info.keys
      end
      log.info "Boot partition devices: #{@underlying_boot_partition_devices}"

      @underlying_boot_partition_devices
    end

    def boot_partition_on_mbr_disk?
      return @boot_partition_on_mbr_disk unless @boot_partition_on_mbr_disk.nil?

      @boot_partition_on_mbr_disk = underlying_boot_partition_devices.any? do |dev|
        pdp = Yast::Storage.GetDiskPartition(dev)
        p_disk = pdp["disk"] || ""
        p_disk == Yast::BootCommon.mbrDisk
      end

      log.info "/boot is on 1st disk: #{@boot_partition_on_mbr_disk}"

      @boot_partition_on_mbr_disk
    end
  end
end
