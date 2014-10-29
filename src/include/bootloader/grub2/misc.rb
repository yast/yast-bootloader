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

require "bootloader/boot_record_backup"

module Yast
  module BootloaderGrub2MiscInclude
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


    # SetBootloaderDevice()
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
    def SetBootloaderDevice(selected_location)
      # first, default to all off:
      Builtins.foreach(["boot_boot", "boot_root", "boot_mbr", "boot_extended"]) do |flag|
        Ops.set(BootCommon.globals, flag, "false")
      end
      # need to remove the boot_custom key to switch this value off
      if Builtins.haskey(BootCommon.globals, "boot_custom")
        BootCommon.globals = Builtins.remove(BootCommon.globals, "boot_custom")
      end

      if selected_location == :root
        Ops.set(BootCommon.globals, "boot_root", "true")
      elsif selected_location == :boot
        Ops.set(BootCommon.globals, "boot_boot", "true")
      elsif selected_location == :mbr
        Ops.set(BootCommon.globals, "boot_mbr", "true")
        # Disable generic MBR as we want grub2 there
        Ops.set(BootCommon.globals, "generic_mbr", "false")
      elsif selected_location == :extended
        Ops.set(BootCommon.globals, "boot_extended", "true")
      end

      nil
    end

    # function check all partitions and it tries to find /boot partition
    # if it is MD Raid and soft-riad return correct device for analyse MBR
    # @param list<map> list of partitions
    # @return [String] device for analyse MBR
    def soft_MDraid_boot_disk(partitions)
      partitions = deep_copy(partitions)
      result = ""
      boot_device = ""
      if BootStorage.BootPartitionDevice != nil &&
          BootStorage.BootPartitionDevice != ""
        boot_device = BootStorage.BootPartitionDevice
      else
        boot_device = BootStorage.RootPartitionDevice
      end

      Builtins.foreach(partitions) do |p|
        if Ops.get_string(p, "device", "") == boot_device
          if Ops.get(p, "type") == :sw_raid &&
              Builtins.tolower(Ops.get_string(p, "fstype", "")) == "md raid"
            device_1 = Ops.get_string(p, ["devices", 0], "")
            Builtins.y2debug("device_1: %1", device_1)
            dp = Storage.GetDiskPartition(device_1)
            Builtins.y2debug("dp: %1", dp)
            result = Ops.get_string(dp, "disk", "")
          end
        end
      end
      Builtins.y2milestone(
        "Device for analyse MBR from soft-raid (MD-Raid only): %1",
        result
      )
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

      dm = Ops.get_map(tm, boot_partition_disk, {})
      partitions_on_boot_partition_disk = Ops.get_list(dm, "partitions", [])
      is_logical = false
      is_logical_and_btrfs = false
      extended = nil

      # determine the underlying devices for the "/boot" partition (either the
      # BootPartitionDevice, or the devices from which the soft-RAID device for
      # "/boot" is built)
      underlying_boot_partition_devices = [BootStorage.BootPartitionDevice]
      md_info = BootCommon.Md2Partitions(BootStorage.BootPartitionDevice)
      if md_info != nil && Ops.greater_than(Builtins.size(md_info), 0)
        boot_partition_is_on_mbr_disk = false
        underlying_boot_partition_devices = Builtins.maplist(md_info) do |dev, bios_id|
          pdp = Storage.GetDiskPartition(dev)
          p_disk = Ops.get_string(pdp, "disk", "")
          boot_partition_is_on_mbr_disk = true if p_disk == BootCommon.mbrDisk
          dev
        end
      end
      Builtins.y2milestone(
        "Boot partition devices: %1",
        underlying_boot_partition_devices
      )

      Builtins.foreach(partitions_on_boot_partition_disk) do |p|
        if Ops.get(p, "type") == :extended
          extended = Ops.get_string(p, "device")
        elsif Builtins.contains(
            underlying_boot_partition_devices,
            Ops.get_string(p, "device", "")
          ) &&
            Ops.get(p, "type") == :logical
          # If any of the underlying_boot_partition_devices can be found on
          # the boot_partition_disk AND is a logical partition, set
          # is_logical to true.
          # For soft-RAID this will not match anyway ("/dev/[hs]da*" does not
          # match "/dev/md*").
          is_logical = true
          is_logical_and_btrfs = true if Ops.get(p, "used_fs") == :btrfs
        end
      end
      Builtins.y2milestone(
        "/boot is on 1st disk: %1",
        boot_partition_is_on_mbr_disk
      )
      Builtins.y2milestone("/boot is in logical partition: %1", is_logical)
      Builtins.y2milestone(
        "/boot is in logical partition and use btrfs: %1",
        is_logical_and_btrfs
      )
      Builtins.y2milestone("The extended partition: %1", extended)

      # if is primary, store bootloader there

      exit = 0
      # there was check if boot device is on logical partition
      # IMO it is good idea check MBR also in this case
      # see bug #279837 comment #53
      if boot_partition_is_on_mbr_disk
        selected_location = BootStorage.BootPartitionDevice !=
          BootStorage.RootPartitionDevice ? :boot : :root
        Ops.set(BootCommon.globals, "activate", "true")
        BootCommon.activate_changed = true

        # check if there is raid and if it soft-raid select correct device for analyse MBR
        # bnc #398356
        if Ops.greater_than(Builtins.size(underlying_boot_partition_devices), 1)
          boot_partition_disk = soft_MDraid_boot_disk(
            partitions_on_boot_partition_disk
          )
        end
        if boot_partition_disk == ""
          boot_partition_disk = Ops.get_string(dp, "disk", "")
        end
        # bnc #483797 cannot read 512 bytes from...
        out = ""
        if boot_partition_disk != ""
          out = BootCommon.examineMBR(boot_partition_disk)
        else
          Builtins.y2error("Boot partition disk not found")
        end
        Ops.set(
          BootCommon.globals,
          "generic_mbr",
          out != "vista" ? "true" : "false"
        )
        if out == "vista"
          Builtins.y2milestone("Vista MBR...")
          vista_mbr = true
        end
      elsif Ops.greater_than(
          Builtins.size(underlying_boot_partition_devices),
          1
        )
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
        Builtins.y2milestone(
          "/boot is on logical parititon and uses btrfs, mbr is favored in this situration"
        )
        selected_location = :mbr
      end

      if !BootStorage.can_boot_from_partition
        Builtins.y2milestone("/boot cannot be used to install stage1")
        selected_location = :mbr
      end

      SetBootloaderDevice(selected_location)
      if !Builtins.contains(
          BootStorage.possible_locations_for_stage1,
          Ops.get(BootCommon.GetBootloaderDevices, 0)
        )
        selected_location = :mbr # default to mbr
        SetBootloaderDevice(selected_location)
      end

      Builtins.y2milestone(
        "grub_ConfigureLocation (%1 on %2)",
        selected_location,
        BootCommon.GetBootloaderDevices
      )

      # set active flag, if needed
      if selected_location == :mbr &&
          Ops.less_or_equal(Builtins.size(underlying_boot_partition_devices), 1)
        # We are installing into MBR:
        # If there is an active partition, then we do not need to activate
        # one (otherwise we do).
        # Reason: if we use our own MBR code, we do not rely on the activate
        # flag in the partition table to boot Linux. Thus, the activated
        # partition can remain activated, which causes less problems with
        # other installed OSes like Windows (older versions assign the C:
        # drive letter to the activated partition).
        Ops.set(
          BootCommon.globals,
          "activate",
          Builtins.size(Storage.GetBootPartition(BootCommon.mbrDisk)) == 0 ? "true" : "false"
        )
      else
        # if not installing to MBR, always activate (so the generic MBR will
        # boot Linux)

        # kokso: fix the problem with proposing installation generic boot code to "/" or "/boot"
        # kokso: if boot device is on logical partition
        if is_logical && extended != nil &&
            (Ops.get(BootCommon.globals, "generic_mbr", "") == "true" || vista_mbr)
          selected_location = :extended
        end
        Ops.set(BootCommon.globals, "activate", "true")
        SetBootloaderDevice(selected_location)
      end

      # for GPT remove protective MBR flag otherwise some systems won't boot
      if gpt_boot_disk?
        BootCommon.pmbr_action = :remove
      end

      Builtins.y2milestone("location configured. Resulting globals #{BootCommon.globals}")

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
      ret = nil

      tm = Storage.GetTargetMap

      device = ""
      if BootStorage.BootPartitionDevice != ""
        device = BootStorage.BootPartitionDevice
      else
        device = BootStorage.RootPartitionDevice
      end

      dp = Storage.GetDiskPartition(device)
      disk = Ops.get_string(dp, "disk", "")
      dm = Ops.get_map(tm, disk, {})
      partitions = Ops.get_list(dm, "partitions", [])
      Builtins.foreach(partitions) do |p|
        ret = Ops.get_string(p, "device") if Ops.get(p, "type") == :extended
      end

      ret
    end

    # Detect "/boot", "/" (root), extended partition device and MBR disk device
    #
    # If no bootloader device has been set up yet (globals["boot_*"]), or the
    # first (FIXME(!)) device is not available as a boot partition, also call
    # grub_ConfigureLocation to configure globals["boot_*"] and set the
    # globals["activate"] and globals["generic_mbr"] flags if needed
    # all these settings are stored in internal variables
    def grub_DetectDisks
      # #151501: AutoYaST also needs to know the activate flag and the
      # "boot_*" settings (formerly the loader_device); jsrain also said
      # that skipping setting these variables is probably a bug:
      # commenting out the skip code, but this may need to be changed and made dependent
      # on a "clone" flag (i.e. make the choice to provide minimal (i.e. let
      # YaST do partial proposals on the target system) or maximal (i.e.
      # stay as closely as possible to this system) info in the AutoYaST XML
      # file)
      # if (Mode::config ())
      #    return;
      mp = Storage.GetMountPoints

      mountdata_boot = Ops.get_list(mp, "/boot", Ops.get_list(mp, "/", []))
      mountdata_root = Ops.get_list(mp, "/", [])

      Builtins.y2milestone("mountPoints %1", mp)
      Builtins.y2milestone("mountdata_boot %1", mountdata_boot)

      BootStorage.RootPartitionDevice = Ops.get_string(mp, ["/", 0], "")

      if BootStorage.RootPartitionDevice == ""
        Builtins.y2error("No mountpoint for / !!")
      end

      # if /boot changed, re-configure location
      BootStorage.BootPartitionDevice = Ops.get_string(
        mountdata_boot,
        0,
        BootStorage.RootPartitionDevice
      )

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
          if !Builtins.contains(all_boot_partitions, dev)
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

      return deep_copy(ret) if Mode.config

      mp = Storage.GetMountPoints
      actual_root = Ops.get_string(mp, ["/", 0], "")
      actual_boot = Ops.get_string(mp, ["/boot", 0], actual_root)
      actual_extended = grub_GetExtendedPartitionDev

      if Ops.get(BootCommon.globals, "boot_boot", "false") == "true" &&
          actual_boot != BootStorage.BootPartitionDevice
        ret = {
          "changed" => true,
          "reason"  => Ops.add(
            Ops.add(
              Ops.add(
                Ops.get_string(ret, "reason", ""),
                "Selected bootloader location \"/boot\" is not on "
              ),
              BootStorage.BootPartitionDevice
            ),
            " any more.\n"
          )
        }
      end

      if Ops.get(BootCommon.globals, "boot_root", "false") == "true" &&
          actual_root != BootStorage.RootPartitionDevice
        ret = {
          "changed" => true,
          "reason"  => Ops.add(
            Ops.add(
              Ops.add(
                Ops.get_string(ret, "reason", ""),
                "Selected bootloader location \"/\" is not on "
              ),
              BootStorage.RootPartitionDevice
            ),
            " any more.\n"
          )
        }
      end

      if Ops.get(BootCommon.globals, "boot_mbr", "false") == "true"
        actual_mbr = BootCommon.FindMBRDisk

        if actual_mbr != BootCommon.mbrDisk
          ret = {
            "changed" => true,
            "reason"  => Ops.add(
              Ops.add(
                Ops.add(
                  Ops.get_string(ret, "reason", ""),
                  "Selected bootloader location MBR is not on "
                ),
                BootCommon.mbrDisk
              ),
              " any more.\n"
            )
          }
        end
      end

      if Ops.get(BootCommon.globals, "boot_extended", "false") == "true" &&
          actual_extended != BootStorage.ExtendedPartitionDevice
        ret = {
          "changed" => true,
          "reason"  => Ops.add(
            Ops.add(
              Ops.add(
                Ops.get_string(ret, "reason", ""),
                "Selected bootloader location \"extended partition\" is not on "
              ),
              BootStorage.ExtendedPartitionDevice
            ),
            " any more.\n"
          )
        }
      end


      if Ops.get(BootCommon.globals, "boot_custom") != nil &&
          Ops.get(BootCommon.globals, "boot_custom") != ""
        all_boot_partitions = BootStorage.possible_locations_for_stage1

        if !Builtins.contains(
            all_boot_partitions,
            Ops.get(BootCommon.globals, "boot_custom")
          )
          ret = {
            "changed" => true,
            "reason"  => Ops.add(
              Ops.add(
                Ops.add(
                  Ops.get_string(ret, "reason", ""),
                  "Selected custom bootloader partition "
                ),
                Ops.get(BootCommon.globals, "boot_custom")
              ),
              " is not available any more.\n"
            )
          }
        end
      end

      if Ops.get_boolean(ret, "changed", false)
        Builtins.y2milestone("Location should be set again")
      end

      deep_copy(ret)
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
      Builtins.y2milestone("globals: %1", BootCommon.globals)
      Builtins.y2milestone("Mode::autoinst: %1", Mode.autoinst)
      Builtins.y2milestone("Mode::autoupg: %1", Mode.autoupgrade)
      Builtins.y2milestone(
        "haskey( BootCommon::globals, boot_boot ): %1",
        Builtins.haskey(BootCommon.globals, "boot_boot")
      )
      md_mbr = ""
      if !BootCommon.was_proposed ||
          # During autoinstall, the autoyast profile must contain a bootloader
          # device specification (we currently really only support system
          # *cloning* with autoyast...). But as a convenience, and because
          # this kind of magic is available for empty globals and sections, we
          # propose a bootloader location if none was specified.
          # Note that "no bootloader device" can be specified by explicitly
          # setting this up, e.g. by setting one or all boot_* flags to
          # "false".
          # FIXME: add to LILO, ELILO; POWERLILO already should have this
          # (check again)
          (Mode.autoinst || Mode.autoupgrade) && !Builtins.haskey(BootCommon.globals, "boot_boot") &&
            !Builtins.haskey(BootCommon.globals, "boot_root") &&
            !Builtins.haskey(BootCommon.globals, "boot_mbr") &&
            !Builtins.haskey(BootCommon.globals, "boot_extended") &&
            !#	    ! haskey( BootCommon::globals, "boot_mbr_md" ) &&
            Builtins.haskey(BootCommon.globals, "boot_custom")
        grub_DetectDisks
        # check whether edd is loaded; if not: load it
        lsmod_command = "lsmod | grep edd"
        Builtins.y2milestone("Running command %1", lsmod_command)
        lsmod_out = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), lsmod_command)
        )
        Builtins.y2milestone("Command output: %1", lsmod_out)
        edd_loaded = Ops.get_integer(lsmod_out, "exit", 0) == 0
        if !edd_loaded
          command = "/sbin/modprobe edd"
          Builtins.y2milestone("Loading EDD module, running %1", command)
          out = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )
          Builtins.y2milestone("Command output: %1", out)
        end
        md_mbr = BootStorage.addMDSettingsToGlobals
        Ops.set(BootCommon.globals, "boot_md_mbr", md_mbr) if md_mbr != ""
      end
      Builtins.y2milestone("(2) globals: %1", BootCommon.globals)

      # refresh device map
      if BootStorage.device_map.empty?  ||
        BootCommon.cached_settings_base_data_change_time !=
            Storage.GetTargetChangeTime &&
            # bnc#585824 - Bootloader doesn't use defined device map from autoyast
            !((Mode.autoinst || Mode.autoupgrade) &&
              BootCommon.cached_settings_base_data_change_time == nil)
        BootStorage.device_map.propose
        md_mbr = BootStorage.addMDSettingsToGlobals
        Ops.set(BootCommon.globals, "boot_md_mbr", md_mbr) if md_mbr != ""
        BootCommon.InitializeLibrary(true, "grub2")
      end

      if !Mode.autoinst && !Mode.autoupgrade
        changed = grub_DisksChanged
        if Ops.get_boolean(changed, "changed", false)
          if BootCommon.askLocationResetPopup(
              Ops.get_string(changed, "reason", "Disk configuration changed.\n")
            )
            SetBootloaderDevice(:none)
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
      BootStorage.device_map.reduce_bios_limit
    end
  end
end
