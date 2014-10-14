require "yast"

require "bootloader/boot_record_backup"

Yast.import "Arch"
Yast.import "BootCommon"
Yast.import "PackageSystem"

module Bootloader
  # this class place generic MBR wherever it is needed
  # and also mark needed partitions with boot flag and legacy_boot
  # FIXME make it single responsibility class
  class MBRUpdate
    include Yast::Logger

    def run
      grub_updateMBR
    end
  private

    def mbr_disk
      @mbr_disk ||= Yast::BootCommon.mbrDisk
    end

    def bootloader_devices
      @bootloader_devices ||= Yast::BootCommon.GetBootloaderDevices
    end

    # Update contents of MBR (active partition and booting code)
    # @return [Boolean] true on success
    def grub_updateMBR
      activate = Yast::BootCommon.globals["activate"] == "true"
      generic_mbr = Yast::BootCommon.globals["generic_mbr"] == "true"

      log.info(
        "Updating disk system area, activate partition: #{activate}, " +
          "install generic boot code in MBR: #{generic_mbr}",
      )

      # After a proposal is done, Bootloader::Propose() always sets
      # backup_mbr to true. The default is false. No other parts of the code
      # currently change this flag.
      if Yast::BootCommon.backup_mbr
        create_backups
      end
      ret = true
      # if the bootloader stage 1 is not installed in the MBR, but
      # ConfigureLocation() asked us to replace some problematic existing
      # MBR, then overwrite the boot code (only, not the partition list!) in
      # the MBR with generic (currently DOS?) bootloader stage1 code
      if generic_mbr &&
          !bootloader_devices.include?(mbr_disk)
        Yast::PackageSystem.Install("syslinux") if !Yast::Stage.initial
        Yast::Builtins.y2milestone(
          "Updating code in MBR: MBR Disk: %1, loader devices: %2",
          mbr_disk,
          bootloader_devices
        )
        mbr_type = Yast::Ops.get_string(
          Yast::Ops.get(Yast::Storage.GetTargetMap, mbr_disk, {}),
          "label",
          ""
        )
        Yast::Builtins.y2milestone("mbr type = %1", mbr_type)
        mbr_file = mbr_type == "gpt" ?
          "/usr/share/syslinux/gptmbr.bin" :
          "/usr/share/syslinux/mbr.bin"

        disks_to_rewrite = grub_getMbrsToRewrite
        Yast::Builtins.foreach(disks_to_rewrite) do |d|
          Yast::Builtins.y2milestone("Copying generic MBR code to %1", d)
          # added fix 446 -> 440 for Vista booting problem bnc #396444
          command = Yast::Builtins.sformat(
            "/bin/dd bs=440 count=1 if=%1 of=%2",
            mbr_file,
            d
          )
          Yast::Builtins.y2milestone("Running command %1", command)
          out = Yast::Convert.to_map(
            Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), command)
          )
          exit = Yast::Ops.get_integer(out, "exit", 0)
          Yast::Builtins.y2milestone("Command output: %1", out)
          ret = ret && 0 == exit
        end
      end

      Yast::Builtins.foreach(grub_getPartitionsToActivate) do |m_activate|
        num = Yast::Ops.get_integer(m_activate, "num", 0)
        mbr_dev = Yast::Ops.get_string(m_activate, "mbr", "")
        raise "INTERNAL ERROR: Data for partition to activate is invalid." if num == 0 || mbr_dev.empty?

        gpt_disk = Yast::Storage.GetDisk(Yast::Storage.GetTargetMap, mbr_disk)["label"] == "gpt"
        # if primary partition on old DOS MBR table, GPT do not have such limit

        if !(Yast::Arch.ppc && gpt_disk) && (gpt_disk || num <= 4)
          Yast::Builtins.y2milestone("Activating partition %1 on %2", num, mbr_dev)
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
          command = Yast::Builtins.sformat(
            "/usr/sbin/parted -s %1 set %2 legacy_boot on",
            mbr_dev,
            num
          )
          Yast::Builtins.y2milestone("Running command %1", command)
          out = Yast::Convert.to_map(
            Yast::WFM.Execute(Yast::Path.new(".local.bash_output"), command)
          )
          Yast::Builtins.y2milestone("Command output: %1", out)

          command = Yast::Builtins.sformat(
            "/usr/sbin/parted -s %1 set %2 boot on",
            mbr_dev,
            num
          )
          Yast::Builtins.y2milestone("Running command %1", command)
          out = Yast::Convert.to_map(
            Yast::WFM.Execute(Yast::Path.new(".local.bash_output"), command)
          )
          exit = Yast::Ops.get_integer(out, "exit", 0)
          Yast::Builtins.y2milestone("Command output: %1", out)
          ret = ret && 0 == exit
        end
      end if activate
      ret
    end

    def create_backups
      log.info(
        "Doing MBR backup: MBR Disk: #{mbr_disk}, loader devices: #{bootloader_devices}"
      )
      disks_to_rewrite = grub_getMbrsToRewrite + bootloader_devices + [mbr_disk]
      disks_to_rewrite.uniq!
      log.info "Creating backup of boot sectors of #{disks_to_rewrite}"
      backups = disks_to_rewrite.map do |d|
        ::Bootloader::BootRecordBackup.new(d)
      end
      backups.each(&:write)
    end

    # Get the list of MBR disks that should be rewritten by generic code
    # if user wants to do so
    # @return a list of device names to be rewritten
    def grub_getMbrsToRewrite
      ret = [mbr_disk]
      md = {}
      underlying_devs = []
      devs = []
      boot_devices = []

      # bnc#494630 - add also boot partitions from soft-raids
      boot_device = Yast::BootCommon.getBootPartition
      if Yast::Builtins.substring(boot_device, 0, 7) == "/dev/md"
        boot_devices = Yast::Builtins.add(boot_devices, boot_device)
        Yast::Builtins.foreach(bootloader_devices) do |dev|
          boot_devices = Yast::Builtins.add(boot_devices, dev)
        end
      else
        boot_devices = bootloader_devices
      end

      # get a list of all bootloader devices or their underlying soft-RAID
      # devices, if necessary
      underlying_devs = Yast::Builtins.maplist(boot_devices) do |dev|
        md = Yast::BootCommon.Md2Partitions(dev)
        if Yast::Ops.greater_than(Yast::Builtins.size(md), 0)
          devs = Yast::Builtins.maplist(md) { |k, v| k }
          next Yast.deep_copy(devs)
        end
        [dev]
      end
      bootloader_base_devices = Yast::Builtins.flatten(underlying_devs)

      # find the MBRs on the same disks as the devices underlying the boot
      # devices; if for any of the "underlying" or "base" devices no device
      # for acessing the MBR can be determined, include mbrDisk in the list
      mbrs = Yast::Builtins.maplist(bootloader_base_devices) do |dev|
        dev = Yast::Ops.get_string(
          grub_getPartitionToActivate(dev),
          "mbr",
          mbr_disk
        )
        dev
      end
      # FIXME: the exact semantics of this check is unclear; but it seems OK
      # to keep this as a sanity check and a check for an empty list;
      # mbrDisk _should_ be included in mbrs; the exact cases for this need
      # to be found and documented though
      # jreidinger: it clears out if md is in boot devices, but none of mbr member is on mbr disk
      if Yast::Builtins.contains(mbrs, mbr_disk)
        ret = Yast::Convert.convert(
          Yast::Builtins.merge(ret, mbrs),
          :from => "list",
          :to   => "list <string>"
        )
      end
      Yast::Builtins.toset(ret)
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
      p_dev = Yast::Storage.GetDiskPartition(loader_device)
      num = Yast::BootCommon.myToInteger(Yast::Ops.get(p_dev, "nr"))
      mbr_dev = Yast::Ops.get_string(p_dev, "disk", "")

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
      if Yast::Builtins.substring(loader_device, 0, 7) == "/dev/md"
        md = Yast::BootCommon.Md2Partitions(loader_device)
        # max. is 255; 256 means "no bios_id found", so to have at least one
        # underlaying device use higher
        min = 257
        device = ""
        Yast::Builtins.foreach(md) do |d, id|
          if Yast::Ops.less_than(id, min)
            min = id
            device = d
          end
        end
        if device != ""
          p_dev2 = Yast::Storage.GetDiskPartition(device)
          num = Yast::BootCommon.myToInteger(Yast::Ops.get(p_dev2, "nr"))
          mbr_dev = Yast::Ops.get_string(p_dev2, "disk", "")
        end
      end

      tm = Yast::Storage.GetTargetMap
      partitions = Yast::Ops.get_list(tm, [mbr_dev, "partitions"], [])
      # do not select swap and do not select BIOS grub partition
      # as it clear its special flags (bnc#894040)
      partitions.select! { |p| p["used_fs"] != :swap && p["fsid"] != Partitions.fsid_bios_grub }
      # (bnc # 337742) - Unable to boot the openSUSE (32 and 64 bits) after installation
      # if loader_device is disk Choose any partition which is not swap to
      # satisfy such bios (bnc#893449)
      if num == 0
        # strange, no partitions on our mbr device, we probably won't boot
        if partitions.empty?
          Yast::Builtins.y2warning("no non-swap partitions for mbr device #{mbr_dev}")
          return {}
        end
        num = partitions.first["nr"]
        Yast::Builtins.y2milestone("loader_device is disk device, so use its #{num} partition")
      end

      if Yast::Ops.greater_than(num, 4)
        Yast::Builtins.y2milestone("Bootloader partition type can be logical")
        Yast::Builtins.foreach(partitions) do |p|
          if Yast::Ops.get(p, "type") == :extended
            num = Yast::Ops.get_integer(p, "nr", num)
            Yast::Builtins.y2milestone("Using extended partition %1 instead", num)
          end
        end
      end

      ret = {
        "num" => num,
        "mbr" => mbr_dev,
        "dev" => Yast::Storage.GetDeviceName(mbr_dev, num)
      }

      Yast::Builtins.y2milestone("Partition for activating: % 1", ret)
      Yast.deep_copy(ret)
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
      boot_device = Yast::BootCommon.getBootPartition
      if Yast::Builtins.substring(boot_device, 0, 7) == "/dev/md"
        boot_devices = Yast::Builtins.add(boot_devices, boot_device)
        Yast::Builtins.foreach(bootloader_devices) do |dev|
          boot_devices = Yast::Builtins.add(boot_devices, dev)
        end
      else
        boot_devices = bootloader_devices
      end

      # get a list of all bootloader devices or their underlying soft-RAID
      # devices, if necessary
      underlying_devs = Yast::Builtins.maplist(boot_devices) do |dev|
        md = Yast::BootCommon.Md2Partitions(dev)
        if Yast::Ops.greater_than(Yast::Builtins.size(md), 0)
          devs = Yast::Builtins.maplist(md) { |k, v| k }
          next deep_copy(devs)
        end
        [dev]
      end
      bootloader_base_devices = Yast::Builtins.flatten(underlying_devs)

      if Yast::Builtins.size(bootloader_base_devices) == 0
        bootloader_base_devices = bootloader_devices
      end
      ret = Yast::Builtins.maplist(bootloader_base_devices) do |partition|
        grub_getPartitionToActivate(partition)
      end
      ret.delete({})

      Yast::Builtins.toset(ret)
    end
  end
end
