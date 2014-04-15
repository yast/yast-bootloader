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
module Yast
  module BootloaderGrub2MiscInclude
    def initialize_bootloader_grub2_misc(include_target)
      textdomain "bootloader"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Mode"
      Yast.import "BootCommon"
      Yast.import "PackageSystem"
      Yast.import "Map"
    end

    # --------------------------------------------------------------
    # --------------------------------------------------------------
    # updateMBR and related stuff, plus InstallingToFloppy() (taken from
    # routines/misc.ycp)

    # Check if installation to floppy is performed
    # @return true if installing bootloader to floppy
    def grub_InstallingToFloppy
      ret = false
      # there is no boot_floppy flag, the installation to floppy devices needs
      # to be specified in the boot_custom flag
      # (FIXME: which is freely editable, as soon as the generic 'selectdevice'
      # widget allows this; also need perl-Bootloader to put the floppy device
      # in the list of the boot_custom widget)
      if Ops.get(BootCommon.globals, "boot_custom") == nil
        ret = false
      elsif Ops.get(BootCommon.globals, "boot_custom") ==
          StorageDevices.FloppyDevice
        ret = true
      elsif Builtins.contains(
          BootStorage.getFloppyDevices,
          Ops.get(BootCommon.globals, "boot_custom")
        )
        ret = true
      end
      Builtins.y2milestone("Installing to floppy: %1", ret)
      ret
    end

    # Given a device name to which we install the bootloader (loader_device),
    # get the name of the partition which should be activated.
    # Also return the device file name of the disk device that corresponds to
    # loader_device (i.e. where the corresponding MBR can be found).
    # @param [String] loader_device string the device to install bootloader to
    # @return a map $[ "dev" : string, "mbr": string, "num": any]
    #  containing device (eg. "/dev/hda4"), disk (eg. "/dev/hda") and
    #  partition number (eg. 4)
    #      * @param boot_partition string the partition holding /boot subtree
    #    map<string,any> getPartitionToActivate (string boot_partition,
    #	string loader_device)
    def grub_getPartitionToActivate(loader_device)
      p_dev = Storage.GetDiskPartition(loader_device)
      num = BootCommon.myToInteger(Ops.get(p_dev, "nr"))
      mbr_dev = Ops.get_string(p_dev, "disk", "")

      # If loader_device is /dev/md* (which means bootloader is installed to
      # /dev/md*), return the info map for the first device in BIOS ID order
      # that underlies the soft-RAID and that has a BIOS ID (devices without
      # BIOS ID are excluded).
      # If no device is found in this way, return the info map for the
      # soft-RAID device ("/dev/md", "/dev/md[0-9]*").
      # FIXME: use ::storage to detect md devices, not by name!
      # FIXME: return info for ALL underlying soft-RAID devices here, so
      # that all MBRs can be backed-up and all partitions that need to be
      # activated can be activated. This requires a map<map<...>> return
      # value, and code on the caller side that evaluates this.
      if Builtins.substring(loader_device, 0, 7) == "/dev/md"
        md = BootCommon.Md2Partitions(loader_device)
        min = 256 # max. is 255; 256 means "no bios_id found"
        device = ""
        Builtins.foreach(md) do |d, id|
          if Ops.less_than(id, min)
            min = id
            device = d
          end
        end
        if device != ""
          p_dev2 = Storage.GetDiskPartition(device)
          num = BootCommon.myToInteger(Ops.get(p_dev2, "nr"))
          mbr_dev = Ops.get_string(p_dev2, "disk", "")
        end
      end
      # If loader_device is a disk device ("/dev/sda"), that means that we
      # install the bootloader to the MBR. In this case, activate /boot
      # partition.
      # (partial fix of #20637)
      # FIXME: necessity and purpose are unclear: if we install the
      # bootloader to the MBR, then why do we need to activate the /boot
      # partition? Stage1 of a GRUB has the first block of the stage2
      # hard-coded inside.
      # This code was added because a /boot partition on a /dev/cciss device
      # was not activated in bug #20637. Anyway, it probably never worked,
      # since the bootloader was not installed to the MBR in that bug (and
      # thus this code is not triggered).
      # The real problem may have been that Storage::GetDiskPartition() did
      # not know how to parse /dev/cciss/c0d0p1, so that the default case at
      # the beginning of this function did not set up correct values. These
      # days, Storage::GetDiskPartition() looks OK with /dev/cciss.
      # Deactivated this code, so that "/boot" does not get activated
      # unecessarily when GRUB stage1 is installed to the MBR anyway (this
      # would unecessarily have broken drive C: detection on older MS
      # operating systems).
      #	else if (num == 0)
      #	{
      #	    p_dev = Storage::GetDiskPartition (boot_partition);
      #	    num = BootCommon::myToInteger( p_dev["nr"]:nil );
      #	    mbr_dev = p_dev["disk"]:"";
      #
      #	    if (size (BootCommon::Md2Partitions (boot_partition)) > 1)
      #	    {
      #		foreach (string k, integer v, BootCommon::Md2Partitions (boot_partition),{
      #		    if (search (k, loader_device) == 0)
      #		    {
      #			p_dev = Storage::GetDiskPartition (k);
      #			num = BootCommon::myToInteger( p_dev["nr"]:nil );
      #			mbr_dev = p_dev["disk"]:"";
      #		    }
      #		});
      #	    }
      #	}

      # (bnc # 337742) - Unable to boot the openSUSE (32 and 64 bits) after installation
      # if loader_device is disk device activate BootStorage::BootPartitionDevice
      if num == 0
        Builtins.y2milestone("loader_device is disk device")
        p_dev = Storage.GetDiskPartition(BootStorage.BootPartitionDevice)
        num = BootCommon.myToInteger(Ops.get(p_dev, "nr"))
      end

      if Ops.greater_than(num, 4)
        Builtins.y2milestone("Bootloader partition type is logical")
        tm = Storage.GetTargetMap
        partitions = Ops.get_list(tm, [mbr_dev, "partitions"], [])
        Builtins.foreach(partitions) do |p|
          if Ops.get(p, "type") == :extended
            num = Ops.get_integer(p, "nr", num)
            Builtins.y2milestone("Using extended partition %1 instead", num)
          end
        end
      end

      ret = {
        "num" => num,
        "mbr" => mbr_dev,
        "dev" => Storage.GetDeviceName(mbr_dev, num)
      }

      Builtins.y2milestone("Partition for activating: %1", ret)
      deep_copy(ret)
    end

    # Get a list of partitions to activate if user wants to activate
    # boot partition
    # @return a list of partitions to activate
    def grub_getPartitionsToActivate
      md = {}
      underlying_devs = []
      devs = []

      boot_devices = []

      # bnc#494630 - add also boot partitions from soft-raids
      boot_device = BootCommon.getBootPartition
      if Builtins.substring(boot_device, 0, 7) == "/dev/md"
        boot_devices = Builtins.add(boot_devices, boot_device)
        Builtins.foreach(BootCommon.GetBootloaderDevices) do |dev|
          boot_devices = Builtins.add(boot_devices, dev)
        end
      else
        boot_devices = BootCommon.GetBootloaderDevices
      end

      # get a list of all bootloader devices or their underlying soft-RAID
      # devices, if necessary
      underlying_devs = Builtins.maplist(boot_devices) do |dev|
        md = BootCommon.Md2Partitions(dev)
        if Ops.greater_than(Builtins.size(md), 0)
          devs = Builtins.maplist(md) { |k, v| k }
          next deep_copy(devs)
        end
        [dev]
      end
      bootloader_base_devices = Builtins.flatten(underlying_devs)

      if Builtins.size(bootloader_base_devices) == 0
        bootloader_base_devices = BootCommon.GetBootloaderDevices
      end
      ret = Builtins.maplist(bootloader_base_devices) do |partition|
        grub_getPartitionToActivate(partition)
      end
      Builtins.toset(ret)
    end

    # Get the list of MBR disks that should be rewritten by generic code
    # if user wants to do so
    # @return a list of device names to be rewritten
    def grub_getMbrsToRewrite
      ret = [BootCommon.mbrDisk]
      md = {}
      underlying_devs = []
      devs = []
      boot_devices = []

      # bnc#494630 - add also boot partitions from soft-raids
      boot_device = BootCommon.getBootPartition
      if Builtins.substring(boot_device, 0, 7) == "/dev/md"
        boot_devices = Builtins.add(boot_devices, boot_device)
        Builtins.foreach(BootCommon.GetBootloaderDevices) do |dev|
          boot_devices = Builtins.add(boot_devices, dev)
        end
      else
        boot_devices = BootCommon.GetBootloaderDevices
      end

      # get a list of all bootloader devices or their underlying soft-RAID
      # devices, if necessary
      underlying_devs = Builtins.maplist(boot_devices) do |dev|
        md = BootCommon.Md2Partitions(dev)
        if Ops.greater_than(Builtins.size(md), 0)
          devs = Builtins.maplist(md) { |k, v| k }
          next deep_copy(devs)
        end
        [dev]
      end
      bootloader_base_devices = Builtins.flatten(underlying_devs)

      # find the MBRs on the same disks as the devices underlying the boot
      # devices; if for any of the "underlying" or "base" devices no device
      # for acessing the MBR can be determined, include mbrDisk in the list
      mbrs = Builtins.maplist(bootloader_base_devices) do |dev|
        dev = Ops.get_string(
          grub_getPartitionToActivate(dev),
          "mbr",
          BootCommon.mbrDisk
        )
        dev
      end
      # FIXME: the exact semantics of this check is unclear; but it seems OK
      # to keep this as a sanity check and a check for an empty list;
      # mbrDisk _should_ be included in mbrs; the exact cases for this need
      # to be found and documented though
      if Builtins.contains(mbrs, BootCommon.mbrDisk)
        ret = Convert.convert(
          Builtins.merge(ret, mbrs),
          :from => "list",
          :to   => "list <string>"
        )
      end
      Builtins.toset(ret)
    end

    # Get last change time of file
    # @param [String] filename string name of file
    # @return [String] last change date as YYYY-MM-DD-HH-MM-SS
    def grub_getFileChangeDate(filename)
      stat = Convert.to_map(SCR.Read(path(".target.stat"), filename))
      ctime = Ops.get_integer(stat, "ctime", 0)
      command = Builtins.sformat(
        "date --date='1970-01-01 00:00:00 %1 seconds' +\"%%Y-%%m-%%d-%%H-%%M-%%S\"",
        ctime
      )
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      c_time = Ops.get_string(out, "stdout", "")
      Builtins.y2debug("File %1: last change %2", filename, c_time)
      c_time
    end

    # Save current MBR to /boot/backup_mbr
    # Also save to /var/lib/YaST2/backup_boot_sectors/%device, if some
    # existing, rename it
    # @param [String] device string name of device
    def grub_saveMBR(device)
      device_file = Builtins.mergestring(Builtins.splitstring(device, "/"), "_")
      device_file_path = Ops.add(
        "/var/lib/YaST2/backup_boot_sectors/",
        device_file
      )
      device_file_path_to_logs = Ops.add("/var/log/YaST2/", device_file)
      SCR.Execute(
        path(".target.bash"),
        "test -d /var/lib/YaST2/backup_boot_sectors || mkdir /var/lib/YaST2/backup_boot_sectors"
      )
      if Ops.greater_than(SCR.Read(path(".target.size"), device_file_path), 0)
        contents = Convert.convert(
          SCR.Read(path(".target.dir"), "/var/lib/YaST2/backup_boot_sectors"),
          :from => "any",
          :to   => "list <string>"
        )
        contents = Builtins.filter(contents) do |c|
          Builtins.regexpmatch(
            c,
            Builtins.sformat("%1-.*-.*-.*-.*-.*-.*", device_file)
          )
        end
        contents = Builtins.sort(contents)
        index = 0
        siz = Builtins.size(contents)
        while Ops.less_than(Ops.add(index, 10), siz)
          SCR.Execute(
            path(".target.remove"),
            Builtins.sformat(
              "/var/lib/YaST2/backup_boot_sectors/%1",
              Ops.get(contents, index, "")
            )
          )
          index = Ops.add(index, 1)
        end
        change_date = grub_getFileChangeDate(device_file_path)
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/bin/mv %1 %1-%2", device_file_path, change_date)
        )
      end
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/dd if=%1 of=%2 bs=512 count=1 2>&1",
          device,
          device_file_path
        )
      )
      # save MBR to yast2 log directory
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/bin/dd if=%1 of=%2 bs=512 count=1 2>&1",
          device,
          device_file_path_to_logs
        )
      )
      if device == BootCommon.mbrDisk
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/bin/dd if=%1 of=%2 bs=512 count=1 2>&1",
            device,
            "/boot/backup_mbr"
          )
        )

        # save thinkpad MBR
        if BootCommon.ThinkPadMBR(device)
          device_file_path_thinkpad = Ops.add(device_file_path, "thinkpadMBR")
          Builtins.y2milestone("Backup thinkpad MBR")
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "cp %1 %2 2>&1",
              device_file_path,
              device_file_path_thinkpad
            )
          )
        end
      end

      nil
    end

    # Update contents of MBR (active partition and booting code)
    # FIXME move tis function to lilolike.ycp
    # @return [Boolean] true on success
    def grub_updateMBR
      # FIXME: do the real thing in perl_Bootloader
      activate = Ops.get(BootCommon.globals, "activate", "false") == "true"
      generic_mbr = Ops.get(BootCommon.globals, "generic_mbr", "false") == "true"

      Builtins.y2milestone(
        "Updating disk system area, activate partition: %1, " +
          "install generic boot code in MBR: %2",
        activate,
        generic_mbr
      )

      # After a proposal is done, Bootloader::Propose() always sets
      # backup_mbr to true. The default is false. No other parts of the code
      # currently change this flag.
      if BootCommon.backup_mbr
        Builtins.y2milestone(
          "Doing MBR backup: MBR Disk: %1, loader devices: %2",
          BootCommon.mbrDisk,
          BootCommon.GetBootloaderDevices
        )
        disks_to_rewrite = Convert.convert(
          Builtins.toset(
            Builtins.merge(
              grub_getMbrsToRewrite,
              Builtins.merge(
                [BootCommon.mbrDisk],
                BootCommon.GetBootloaderDevices
              )
            )
          ),
          :from => "list",
          :to   => "list <string>"
        )
        Builtins.y2milestone(
          "Creating backup of boot sectors of %1",
          disks_to_rewrite
        )
        Builtins.foreach(disks_to_rewrite) { |d| grub_saveMBR(d) }
      end
      ret = true
      # if the bootloader stage 1 is not installed in the MBR, but
      # ConfigureLocation() asked us to replace some problematic existing
      # MBR, then overwrite the boot code (only, not the partition list!) in
      # the MBR with generic (currently DOS?) bootloader stage1 code
      if generic_mbr &&
          !Builtins.contains(
            BootCommon.GetBootloaderDevices,
            BootCommon.mbrDisk
          )
        PackageSystem.Install("syslinux") if !Stage.initial
        Builtins.y2milestone(
          "Updating code in MBR: MBR Disk: %1, loader devices: %2",
          BootCommon.mbrDisk,
          BootCommon.GetBootloaderDevices
        )
        mbr_type = Ops.get_string(
          Ops.get(Storage.GetTargetMap, BootCommon.mbrDisk, {}),
          "label",
          ""
        )
        Builtins.y2milestone("mbr type = %1", mbr_type)
        mbr_file = mbr_type == "gpt" ?
          "/usr/share/syslinux/gptmbr.bin" :
          "/usr/share/syslinux/mbr.bin"

        disks_to_rewrite = grub_getMbrsToRewrite
        Builtins.foreach(disks_to_rewrite) do |d|
          Builtins.y2milestone("Copying generic MBR code to %1", d)
          # added fix 446 -> 440 for Vista booting problem bnc #396444
          command = Builtins.sformat(
            "/bin/dd bs=440 count=1 if=%1 of=%2",
            mbr_file,
            d
          )
          Builtins.y2milestone("Running command %1", command)
          out = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )
          exit = Ops.get_integer(out, "exit", 0)
          Builtins.y2milestone("Command output: %1", out)
          ret = ret && 0 == exit
        end
      end

      Builtins.foreach(grub_getPartitionsToActivate) do |m_activate|
        num = Ops.get_integer(m_activate, "num", 0)
        mbr_dev = Ops.get_string(m_activate, "mbr", "")
        if num != 0 && mbr_dev != ""
          # if primary partition
          if !Ops.is_integer?(num) || Ops.less_or_equal(num, 4)
            Builtins.y2milestone("Activating partition %1 on %2", num, mbr_dev)
            # FIXME: this is the most rotten code since molded sliced bread
            # move to bootloader/Core/GRUB.pm or similar
            # TESTME: make sure that parted does not destroy BSD
            # slices (#suse24740): cf. section 5.1 of "info parted":
            #   Parted only supports the BSD disk label system.
            #   Parted is unlikely to support the partition slice
            #   system in the future because the semantics are rather
            #   strange, and don't work like "normal" partition tables
            #   do.
            # FIXED: investigate proper handling of the activate flag
            # (kernel ioctls in parted etc.) and fix parted

            # this is needed only on gpt disks but we run it always
            # anyway; parted just fails, then
            command = Builtins.sformat(
              "/usr/sbin/parted -s %1 set %2 legacy_boot on",
              mbr_dev,
              num
            )
            Builtins.y2milestone("Running command %1", command)
            out = Convert.to_map(
              WFM.Execute(path(".local.bash_output"), command)
            )
            Builtins.y2milestone("Command output: %1", out)

            command = Builtins.sformat(
              "/usr/sbin/parted -s %1 set %2 boot on",
              mbr_dev,
              num
            )
            Builtins.y2milestone("Running command %1", command)
            out = Convert.to_map(
              WFM.Execute(path(".local.bash_output"), command)
            )
            exit = Ops.get_integer(out, "exit", 0)
            Builtins.y2milestone("Command output: %1", out)
            ret = ret && 0 == exit
          end
        else
          Builtins.y2error("Cannot activate %1", m_activate)
        end
      end if activate
      ret
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

      SetBootloaderDevice(selected_location)
      if !Builtins.contains(
          BootStorage.getPartitionList(:boot, "grub"),
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

      selected_location
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
      all_boot_partitions = BootStorage.getPartitionList(:boot, "grub")
      bldevs = BootCommon.GetBootloaderDevices
      need_location_reconfigure = false

      if bldevs == nil || bldevs == ["/dev/null"]
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
        all_boot_partitions = BootStorage.getPartitionList(:boot, "grub")

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
          Mode.autoinst && !Builtins.haskey(BootCommon.globals, "boot_boot") &&
            !Builtins.haskey(BootCommon.globals, "boot_root") &&
            !Builtins.haskey(BootCommon.globals, "boot_mbr") &&
            !Builtins.haskey(BootCommon.globals, "boot_extended") &&
            !#	    ! haskey( BootCommon::globals, "boot_mbr_md" ) &&
            Builtins.haskey(BootCommon.globals, "boot_custom")
        grub_DetectDisks
        BootCommon.del_parts = BootStorage.getPartitionList(:deleted, "grub")
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
      if BootStorage.device_mapping == nil ||
          Builtins.size(BootStorage.device_mapping) == 0 ||
          BootCommon.cached_settings_base_data_change_time !=
            Storage.GetTargetChangeTime &&
            # bnc#585824 - Bootloader doesn't use defined device map from autoyast
            !(Mode.autoinst &&
              BootCommon.cached_settings_base_data_change_time == nil)
        BootStorage.ProposeDeviceMap
        md_mbr = BootStorage.addMDSettingsToGlobals
        Ops.set(BootCommon.globals, "boot_md_mbr", md_mbr) if md_mbr != ""
        BootCommon.InitializeLibrary(true, "grub")
      end

      if !Mode.autoinst
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


    # FATE #301994 - Correct device mapping in case windows is installed on the second HD
    # Check if chainloader section with windows is on the first disk
    #
    # @param [Hash{String => Object}] section from  BootCommon::sections
    # @return [Boolean] true if it is necessary remap section
    def isWidnowsOnBootDisk(section)
      section = deep_copy(section)
      # check if it is windows chainloader
      if Builtins.search(
          Builtins.tolower(Ops.get_string(section, "name", "")),
          "windows"
        ) != nil ||
          Builtins.search(
            Builtins.tolower(Ops.get_string(section, "original_name", "")),
            "windows"
          ) != nil
        p_dev = Storage.GetDiskPartition(
          Ops.get_string(section, "chainloader", "")
        )

        disk_dev = Ops.get_string(p_dev, "disk", "")
        if disk_dev == ""
          Builtins.y2error("trying find disk for windows chainloader failed")
          return false
        end
        # find grub id in device map for chainloader device
        grub_id = Ops.get(BootStorage.device_mapping, disk_dev, "")
        Builtins.y2milestone(
          "Disk from windows chainloader: %1 grub id from device map: %2",
          disk_dev,
          grub_id
        )

        # check if disk is the first in order...
        return true if grub_id != "hd0"
      end
      false
    end

    # FATE #301994 - Correct device mapping in case windows is installed on the second HD
    # Remap and make active windows chainloader section
    # if it is not on the boot (the first) disk
    # @param list of sections
    # @return [Array] of sections

    def checkWindowsSection(sections)
      sections = deep_copy(sections)
      # list of idexes from sections where is chainloader
      # and where is necessary add remapping and makeactive
      list_index = []
      # counter
      index = -1
      # check all sections...
      Builtins.foreach(sections) do |section|
        index = Ops.add(index, 1)
        if Builtins.haskey(section, "chainloader")
          Builtins.y2debug("chainloader section: %1", section)
          # add only indexes for update
          if isWidnowsOnBootDisk(section)
            list_index = Builtins.add(list_index, index)
          end
        end
      end

      if Ops.greater_than(Builtins.size(list_index), 0)
        Builtins.foreach(list_index) do |idx|
          Ops.set(sections, [idx, "remap"], "true")
          Ops.set(sections, [idx, "makeactive"], "true")
          Builtins.y2milestone(
            "Added remap and makeactive for section: %1",
            Ops.get(sections, idx, {})
          )
        end
      end

      Builtins.y2debug(
        "Checking sections for windows chainloader: %1",
        sections
      )
      deep_copy(sections)
    end


    # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
    # The function reduces records (devices) in device.map
    # Grub doesn't support more than 8 devices in device.map
    # @return [Boolean] true if device map was reduced
    def ReduceDeviceMapTo8
      result = false

      if Ops.greater_than(Builtins.size(BootStorage.device_mapping), 8)
        result = true
        bios_order = Convert.convert(
          Map.Values(BootStorage.device_mapping),
          :from => "list",
          :to   => "list <string>"
        )
        #delete all grub devices with order more than 9
        bios_order = Builtins.filter(bios_order) do |key|
          Ops.less_than(Builtins.size(key), 4)
        end
        bios_order = Builtins.lsort(bios_order)
        Builtins.y2debug("ordered values (grub devices): %1", bios_order)
        inverse_device_map = {}
        new_device_map = {}
        Builtins.y2milestone(
          "Device map before reducing: %1",
          BootStorage.device_mapping
        )
        Builtins.foreach(BootStorage.device_mapping) do |key, value|
          Ops.set(inverse_device_map, value, key)
        end

        Builtins.y2debug("inverse_device_map: %1", inverse_device_map)
        index = 0

        Builtins.foreach(bios_order) do |key|
          device_name = Ops.get(inverse_device_map, key, "")
          if Ops.less_than(index, 8)
            Builtins.y2debug(
              "adding device: %1 with key: %2 and index is: %3",
              device_name,
              key,
              index
            )
            Ops.set(new_device_map, device_name, key)
            index = Ops.add(index, 1)
          else
            raise Break
          end
        end
        BootStorage.device_mapping = deep_copy(new_device_map)
        Builtins.y2milestone(
          "Device map after reducing: %1",
          BootStorage.device_mapping
        )
      else
        Builtins.y2milestone(
          "Device map includes less than 9 devices. It is not reduced. device_map: %1",
          BootStorage.device_mapping
        )
      end
      result
    end


    # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
    # The function check if boot device is in device.map
    # Grub doesn't support more than 8 devices in device.map
    # @param string boot device
    # @param string boot device with name by mountby
    # @return [Boolean] true if there is missing boot device
    def checkBootDeviceInDeviceMap(boot_dev, boot_dev_mountby)
      result = false

      if Ops.greater_than(Builtins.size(BootStorage.device_mapping), 8)
        result = false
        bios_order = Convert.convert(
          Map.Values(BootStorage.device_mapping),
          :from => "list",
          :to   => "list <string>"
        )
        #delete all grub devices with order more than 9
        bios_order = Builtins.filter(bios_order) do |key|
          Ops.less_than(Builtins.size(key), 4)
        end
        bios_order = Builtins.lsort(bios_order)
        Builtins.y2debug("ordered values (grub devices): %1", bios_order)
        inverse_device_map = {}
        Builtins.foreach(BootStorage.device_mapping) do |key, value|
          Ops.set(inverse_device_map, value, key)
        end

        Builtins.y2debug("inverse_device_map: %1", inverse_device_map)
        index = 0
        boot_device_added = false
        Builtins.foreach(bios_order) do |key|
          device_name = Ops.get(inverse_device_map, key, "")
          if Ops.less_than(index, 8)
            if device_name == boot_dev || device_name == boot_dev_mountby
              boot_device_added = true
            end
            index = Ops.add(index, 1)
          else
            if boot_device_added
              Builtins.y2milestone("Device map includes boot disk")
              raise Break
            else
              Builtins.y2error("Device map doesn't include boot disk")
              result = true
              raise Break
            end
          end
        end
      else
        Builtins.y2milestone("Device map includes less than 9 devices.")
      end
      result
    end
  end
end
