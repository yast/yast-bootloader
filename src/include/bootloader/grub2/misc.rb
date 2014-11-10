# encoding: utf-8

# File:
#      modules/BootGRUB2.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB2 configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id: BootGRUB.ycp 63508 2011-03-04 12:53:27Z jreidinger $
#

require "yast"
require "bootloader/boot_record_backup"

module Yast
  module BootloaderGrub2MiscInclude
    include Yast::Logger

    def initialize_bootloader_grub2_misc(include_target)
      textdomain "bootloader"
      Yast.import "Arch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Map"
      Yast.import "Mode"
      Yast.import "PackageSystem"
      Yast.import "Partitions"
      Yast.import "Storage"
      Yast.import "StorageDevices"
    end

    # --------------------------------------------------------------
    # --------------------------------------------------------------
    # LocationProposal() and related stuff (taken from routines/lilolike.ycp)


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
        BootCommon.globals[flag] = "false"
      end
      # need to remove the boot_custom key to switch this value off
      BootCommon.globals.delete("boot_custom")

      case selected_location
      when :root then BootCommon.globals["boot_root"] = "true"
      when :boot then BootCommon.globals["boot_boot"] = "true"
      when :extended then BootCommon.globals["boot_extended"] = "true"
      when :mbr
        BootCommon.globals["boot_mbr"] = "true"
        # Disable generic MBR as we want grub2 there
        BootCommon.globals["generic_mbr"] = "false"
      when :none
        log.info "Resetting bootloader device"
      else
        raise "Unknown value to select bootloader device #{selected_location.inspect}"
      end
    end

    # function check all partitions and it tries to find /boot partition
    # if it is MD Raid and soft-riad return correct device for analyse MBR
    # @param list<map> list of partitions
    # @return [String] device for analyse MBR
    def mdraid_boot_disk(partitions)
      boot_device = BootStorage.BootPartitionDevice
      boot_part = partitions.find { |p| p["device"] == boot_device }
      return "" if boot_part["fstype"] != "md raid" # we are intersted only in raids

      result = boot_part["devices"].first
      result = Storage.GetDiskPartition(result)["disk"]

      log.info "Device for analyse MBR from soft-raid (MD-Raid only): #{result}"
      result
    end

    # grub_ConfigureLocation()
    # Where to install the bootloader.
    # Returns the type of device where to install: one of `boot `root `mbr `extended `mbr_md
    # Also sets the boot_* keys in the internal global variable globals accordingly.
    #
    # @return [String] type of location proposed to bootloader
    def grub_ConfigureLocation
      # NOTE: selected_location is a temporary local variable now; the global
      # variable is not used for grub anymore
      selected_location = :mbr # default to mbr

      vista_mbr = false
      # check whether the /boot partition
      #  - is primary:				is_logical  -> false
      #  - is on the first disk (with the MBR):  boot_partition_is_on_mbr_disk -> true

      tm = Storage.GetTargetMap
      dp = Storage.GetDiskPartition(BootStorage.BootPartitionDevice)
      boot_partition_disk = Ops.get_string(dp, "disk", "")
      boot_partition_is_on_mbr_disk = boot_partition_disk == BootCommon.mbrDisk

      dm = tm[boot_partition_disk] || {}
      partitions_on_boot_partition_disk = dm["partitions"] || []
      is_logical = false
      is_logical_and_btrfs = false
      extended = nil

      # determine the underlying devices for the "/boot" partition (either the
      # BootPartitionDevice, or the devices from which the soft-RAID device for
      # "/boot" is built)
      underlying_boot_partition_devices = [BootStorage.BootPartitionDevice]
      md_info = BootCommon.Md2Partitions(BootStorage.BootPartitionDevice)
      if !md_info.empty?
        boot_partition_is_on_mbr_disk = false
        underlying_boot_partition_devices = Builtins.maplist(md_info) do |dev, bios_id|
          pdp = Storage.GetDiskPartition(dev)
          p_disk = pdp["disk"] || ""
          boot_partition_is_on_mbr_disk = true if p_disk == BootCommon.mbrDisk
          dev
        end
      end
      log.info "Boot partition devices: #{underlying_boot_partition_devices}"

      partitions_on_boot_partition_disk.each do |p|
        if p["type"] == :extended
          extended = p["device"]
        elsif underlying_boot_partition_devices.include?(p["device"]) &&
            p["type"] == :logical
          # If any of the underlying_boot_partition_devices can be found on
          # the boot_partition_disk AND is a logical partition, set
          # is_logical to true.
          # For soft-RAID this will not match anyway ("/dev/[hs]da*" does not
          # match "/dev/md*").
          is_logical = true
          is_logical_and_btrfs = true if p["used_fs"] == :btrfs
        end
      end
      log.info "/boot is on 1st disk: #{boot_partition_is_on_mbr_disk}"
      log.info "/boot is in logical partition: #{is_logical}"
      log.info "/boot is in logical partition and use btrfs: #{is_logical_and_btrfs}"
      log.info "The extended partition: #{extended}"

      # if is primary, store bootloader there

      exit = 0
      # there was check if boot device is on logical partition
      # IMO it is good idea check MBR also in this case
      # see bug #279837 comment #53
      if boot_partition_is_on_mbr_disk
        selected_location = BootStorage.BootPartitionDevice !=
          BootStorage.RootPartitionDevice ? :boot : :root
        BootCommon.globals["activate"] = "true"
        BootCommon.activate_changed = true

        # check if there is raid and if it soft-raid select correct device for analyse MBR
        # bnc #398356
        if underlying_boot_partition_devices.size > 1
          boot_partition_disk = mdraid_boot_disk(partitions_on_boot_partition_disk)
        end
        if boot_partition_disk.empty?
          boot_partition_disk = dp["disk"] || ""
        end
        # bnc #483797 cannot read 512 bytes from...
        raise "Boot partition disk not found" if boot_partition_disk.empty?
        out = BootCommon.examineMBR(boot_partition_disk)
        BootCommon.globals["generic_mbr"] = out != "vista" ? "true" : "false"
        if out == "vista"
          Builtins.y2milestone("Vista MBR...")
          vista_mbr = true
        end
      elsif underlying_boot_partition_devices.size > 1
        # FIXME: `mbr_md is probably unneeded; AFA we can see, this decision is
        # automatic anyway and perl-Bootloader should be able to make it without help
        # from the user or the proposal.
        # In one or two places yast2-bootloader needs to find out all underlying MBR
        # devices, if we install stage 1 to a soft-RAID. These places need to find out
        # themselves if we have MBRs on a soft-RAID or not.
        # selected_location = `mbr_md;
        selected_location = :mbr
      end

      if is_logical_and_btrfs
        log.info "/boot is on logical parititon and uses btrfs, mbr is favored in this situration"
        selected_location = :mbr
      end

      if !BootStorage.can_boot_from_partition
        log.info "/boot cannot be used to install stage1"
        selected_location = :mbr
      end

      assign_bootloader_device(selected_location)
      if !BootStorage.possible_locations_for_stage1.include?(BootCommon.GetBootloaderDevices.first)
        selected_location = :mbr # default to mbr
        assign_bootloader_device(selected_location)
      end

      log.info "grub_ConfigureLocation (#{selected_location} on #{BootCommon.GetBootloaderDevices})"

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
        BootCommon.globals["activate"] = Storage.GetBootPartition(BootCommon.mbrDisk).empty? ? "true" : "false"
      else
        # if not installing to MBR, always activate (so the generic MBR will
        # boot Linux)

        # kokso: fix the problem with proposing installation generic boot code to "/" or "/boot"
        # kokso: if boot device is on logical partition
        if is_logical && extended != nil &&
            (BootCommon.globals["generic_mbr"] == "true" || vista_mbr)
          selected_location = :extended
        end
        BootCommon.globals["activate"] = "true"
        assign_bootloader_device(selected_location)
      end

      # for GPT remove protective MBR flag otherwise some systems won't boot
      if gpt_boot_disk?
        BootCommon.pmbr_action = :remove
      end

      log.info "location configured. Resulting globals #{BootCommon.globals}"

      selected_location
    end

    def gpt_boot_disk?
      targets = BootCommon.GetBootloaderDevices
      boot_discs = targets.map {|d| Storage.GetDisk(Storage.GetTargetMap, d)}
      boot_discs.any? {|d| d["label"] == "gpt" }
    end

    # Find extended partition device (if it exists) on the same device where the
    # BootPartitionDevice is located
    #
    # BootPartitionDevice must be set
    #
    # @return [String] device name of extended partition, or nil if none found
    def grub_GetExtendedPartitionDev

      tm = Storage.GetTargetMap
      device = BootStorage.BootPartitionDevice
      dp = Storage.GetDiskPartition(device)
      dm = tm[dp["disk"]] || {}
      partitions = dm["partitions"] || []
      ext_part = partitions.find { |p| p["type"] == :extended }
      return nil unless ext_part

      ext_part["device"]
    end

    # Detect "/boot", "/" (root), extended partition device and MBR disk device
    #
    # If no bootloader device has been set up yet (globals["boot_*"]), or the
    # first (FIXME(!)) device is not available as a boot partition, also call
    # grub_ConfigureLocation to configure globals["boot_*"] and set the
    # globals["activate"] and globals["generic_mbr"] flags if needed
    # all these settings are stored in internal variables
    def grub_DetectDisks
      mp = Storage.GetMountPoints

      mountdata_boot = mp["/boot"] || mp["/"]
      mountdata_root = mp["/"]

      log.info "mountPoints #{mp}"
      log.info "mountdata_boot #{mountdata_boot}"

      BootStorage.RootPartitionDevice = mountdata_root.first || ""
      raise "No mountpoint for / !!" if BootStorage.RootPartitionDevice.empty?

      # if /boot changed, re-configure location
      BootStorage.BootPartitionDevice = mountdata_boot.first

      # get extended partition device (if exists)
      BootStorage.ExtendedPartitionDevice = grub_GetExtendedPartitionDev

      if BootCommon.mbrDisk == "" || BootCommon.mbrDisk == nil
        # mbr detection.
        BootCommon.mbrDisk = BootCommon.FindMBRDisk
      end

      # if no bootloader devices have been set up, or any of the set up
      # bootloader devices have become unavailable, then re-propose the
      # bootloader location.
      all_boot_partitions = BootStorage.possible_locations_for_stage1
      bldevs = BootCommon.GetBootloaderDevices
      need_location_reconfigure = false

      if bldevs.empty?
        need_location_reconfigure = true
      else
        Builtins.foreach(bldevs) do |dev|
          if !all_boot_partitions.include?(dev)
            need_location_reconfigure = true
          end
        end
      end

      grub_ConfigureLocation if need_location_reconfigure

      nil
    end

    # Check whether any disk settings for the disks we currently use were changed
    # since last checking
    # @return [Hash] map containing boolean "changed" and string "reason"
    def grub_DisksChanged
      ret = { "changed" => false, "reason" => "" }
      return ret if Mode.config

      mp = Storage.GetMountPoints
      actual_root = mp["/"].first || ""
      actual_boot = mp["/boot"].first || actual_root
      actual_extended = grub_GetExtendedPartitionDev

      if BootCommon.globals["boot_boot"] == "true" &&
          actual_boot != BootStorage.BootPartitionDevice
        ret["changed"] = true
        ret["reason"] +=
          _("Selected bootloader location \"/boot\" is not on %s any more.\n") %
            BootStorage.BootPartitionDevice
      end

      if BootCommon.globals["boot_root"] == "true" &&
          actual_root != BootStorage.RootPartitionDevice
        ret["changed"] = true
        ret["reason"] +=
          _("Selected bootloader location \"/\" is not on %s any more.\n") %
            BootStorage.RootPartitionDevice
      end

      if BootCommon.globals["boot_mbr"] == "true"
        actual_mbr = BootCommon.FindMBRDisk

        if actual_mbr != BootCommon.mbrDisk
          ret["changed"] = true
          ret["reason"] +=
            _("Selected bootloader location MBR is not on %s any more.\n") %
              BootCommon.mbrDisk
        end
      end

      if BootCommon.globals["boot_extended"] == "true" &&
          actual_extended != BootStorage.ExtendedPartitionDevice

        ret["changed"] = true
        ret["reason"] +=
          _("Selected bootloader location \"extended partition\" is not on %s any more.\n") %
            BootStorage.ExtendedPartitionDevice
      end


      if BootCommon.globals["boot_custom"] &&
          !BootCommon.globals["boot_custom"].empty?
        all_boot_partitions = BootStorage.possible_locations_for_stage1

        if !all_boot_partitions.include?(BootCommon.globals["boot_custom"])
          ret["changed"] = true
          ret["reason"] +=
            _("Selected custom bootloader partition %s is not available any more.\n") %
              BootStorage.ExtendedPartitionDevice
        end
      end

      if ret["changed"]
        log.info "Location should be set again"
      end

      ret
    end

    # Propose the boot loader location for grub
    #  - if no proposal has been made, collects the devices for "/", "/boot", MBR
    #    and makes a new proposal
    #  - if no device mapping exists, creates a device mapping
    #  - if the devices that were somehow (proposal, user interface) selected for
    #    bootloader installation do not match the current partitioning any more
    #    (e.g. "/boot" partition was selected but is not available anymore (and
    #    "/" did not move there), "/" was selected but has moved, etc.), then also
    #    re-collect the devices for "/", "/boot", MBR and make a new proposal
    def grub_LocationProposal
      log.info "globals: #{BootCommon.globals}"
      log.info "Mode #{Mode.mode}"
      md_mbr = ""
      no_boot_key = ["boot_boot", "boot_root", "boot_mbr", "boot_extended", "boot_custom"].none? do |k|
        BootCommon.globals[k]
      end
      if !BootCommon.was_proposed ||
          # During autoinstall, the autoyast profile must contain a bootloader
          # device specification (we currently really only support system
          # *cloning* with autoyast...). But as a convenience, and because
          # this kind of magic is available for empty globals and sections, we
          # propose a bootloader location if none was specified.
          # Note that "no bootloader device" can be specified by explicitly
          # setting this up, e.g. by setting one or all boot_* flags to
          # "false".
          (Mode.autoinst || Mode.autoupgrade) && no_boot_key
        grub_DetectDisks
        # check whether edd is loaded; if not: load it
        lsmod_command = "lsmod | grep edd"
        lsmod_out = SCR.Execute(path(".target.bash_output"), lsmod_command)
        log.info "Command '#{lsmod_command}' output: #{lsmod_out}"
        edd_loaded = Ops.get_integer(lsmod_out, "exit", 0) == 0
        if !edd_loaded
          command = "/sbin/modprobe edd"
          out = SCR.Execute(path(".target.bash_output"), command)
          log.info "Command '#{command}' output: #{out}"
        end
        md_mbr = BootStorage.addMDSettingsToGlobals
        BootCommon.globals["boot_md_mbr"] = md_mbr unless md_mbr.empty?
      end
      log.info "(2) globals: #{BootCommon.globals}"

      # refresh device map
      if BootStorage.device_map.empty?  ||
        BootCommon.cached_settings_base_data_change_time !=
            Storage.GetTargetChangeTime &&
            # bnc#585824 - Bootloader doesn't use defined device map from autoyast
            !((Mode.autoinst || Mode.autoupgrade) &&
              BootCommon.cached_settings_base_data_change_time == nil)
        BootStorage.device_map.propose
        BootCommon.InitializeLibrary(true, "grub2")
      end

      if !Mode.autoinst && !Mode.autoupgrade
        changed = grub_DisksChanged
        if changed["changed"]
          if BootCommon.askLocationResetPopup(changed["reason"])
            assign_bootloader_device(:none)
            Builtins.y2milestone("Reconfiguring locations")
            grub_DetectDisks
          end
        end
      end

      nil
    end

    # --------------------------------------------------------------
    # --------------------------------------------------------------
    # other stuff

    # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
    # The function reduces records (devices) in device.map
    # Grub doesn't support more than 8 devices in device.map
    # @return [Boolean] true if device map was reduced
    def ReduceDeviceMapTo8
      BootStorage.device_map.reduce_to_bios_limit
    end
  end
end
