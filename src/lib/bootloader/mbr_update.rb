require "yast"

require "bootloader/boot_record_backup"

Yast.import "Arch"
Yast.import "BootCommon"
Yast.import "PackageSystem"
Yast.import "Partitions"

module Bootloader
  # this class place generic MBR wherever it is needed
  # and also mark needed partitions with boot flag and legacy_boot
  # FIXME make it single responsibility class
  class MBRUpdate
    include Yast::Logger

    # Update contents of MBR (active partition and booting code)
    # @return [Boolean] true on success
    def run
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
        ret &&= install_generic_mbr
      end

      if activate
        ret &&= activate_partitions
      end

      ret
    end
  private

    def mbr_disk
      @mbr_disk ||= Yast::BootCommon.mbrDisk
    end

    def bootloader_devices
      @bootloader_devices ||= Yast::BootCommon.GetBootloaderDevices
    end

    def create_backups
      devices_to_backup = disks_to_rewrite + bootloader_devices + [mbr_disk]
      devices_to_backup.uniq!
      log.info "Creating backup of boot sectors of #{devices_to_backup}"
      backups = devices_to_backup.map do |d|
        ::Bootloader::BootRecordBackup.new(d)
      end
      backups.each(&:write)
    end

    def mbr_is_gpt?
      mbr_storage_object = Yast::Storage.GetTargetMap[mbr_disk]
      raise "Cannot find in storage mbr disk #{mbr_disk}" unless mbr_storage_object
      mbr_type = mbr_storage_object["label"]
      log.info("mbr type = #{mbr_type}")
      mbr_type == "gpt"
    end

    def generic_mbr_file
      @generic_mbr_file ||= mbr_is_gpt? ?
        "/usr/share/syslinux/gptmbr.bin" :
        "/usr/share/syslinux/mbr.bin"
    end

    def install_generic_mbr
      Yast::PackageSystem.Install("syslinux") unless Yast::Stage.initial
      ret = true
      disks_to_rewrite.each do |disk|
        log.info("Copying generic MBR code to #{disk}")
        # added fix 446 -> 440 for Vista booting problem bnc #396444
        command = "/bin/dd bs=440 count=1 if=#{generic_mbr_file} of=#{disk}"
        out = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), command)
        log.info "Command `#{command}` output: #{out}"
        ret &&= out["exit"] == 0
      end
      return ret
    end

    def activate_partitions
      ret = true
      grub_getPartitionsToActivate.each do |m_activate|
        num = m_activate["num"]
        mbr_dev = m_activate["mbr"]
        raise "INTERNAL ERROR: Data for partition to activate is invalid." if num.nil? || mbr_dev.nil?

        gpt_disk = mbr_is_gpt?
        # if primary partition on old DOS MBR table, GPT do not have such limit

        if !(Yast::Arch.ppc && gpt_disk) && (gpt_disk || num <= 4)
          log.info "Activating partition #{num} on #{mbr_dev}"
          # this is needed only on gpt disks but we run it always
          # anyway; parted just fails, then
          command = "/usr/sbin/parted -s #{mbr_dev} set #{num} legacy_boot on"
          out = Yast::WFM.Execute(Yast::Path.new(".local.bash_output"), command)
          log.info "Command `#{command}` output: #{out}"

          command = "/usr/sbin/parted -s #{mbr_dev} set #{num} boot on"
          out = Yast::WFM.Execute(Yast::Path.new(".local.bash_output"), command)
          log.info "Command `#{command}` output: #{out}"
          ret &&= out["exit"] == 0
        end
      end
      ret
    end

    def boot_devices
      if !@boot_devices
        @boot_devices = bootloader_devices.dup

        boot_device = Yast::BootCommon.getBootPartition
        # bnc#494630 - add also boot partitions from soft-raids
        @boot_devices += [boot_device] if boot_device.start_with?("/dev/md")
      end

      return @boot_devices
    end

    # get a list of all bootloader devices or their underlying soft-RAID
    # devices, if necessary
    def base_devices
      @bootloader_base_devices ||= boot_devices.reduce([]) do |res, dev|
        md = Yast::BootCommon.Md2Partitions(dev)
        if md.empty?
          res << dev
        else
          res.concat(md.keys)
        end
      end
    end

    # Get the list of MBR disks that should be rewritten by generic code
    # if user wants to do so
    # @return a list of device names to be rewritten
    def disks_to_rewrite
      # find the MBRs on the same disks as the devices underlying the boot
      # devices; if for any of the "underlying" or "base" devices no device
      # for acessing the MBR can be determined, include mbrDisk in the list
      mbrs = base_devices.map do |dev|
        partition_to_activate(dev)["mbr"] || mbr_disk
      end
      # FIXME: the exact semantics of this check is unclear; but it seems OK
      # to keep this as a sanity check and a check for an empty list;
      # mbrDisk _should_ be included in mbrs; the exact cases for this need
      # to be found and documented though
      # jreidinger: it clears out if md is in boot devices, but none of md members is on mbr disk
      ret = [mbr_disk]
      if mbrs.include?(mbr_disk)
        ret.concat(mbrs)
      end
      ret.uniq
    end

    def first_base_device_to_boot(md_device)
      md = Yast::BootCommon.Md2Partitions(md_device)
      md.reduce do |res, items|
        device, bios_id = items
        next device unless res

        bios_id < md[res] ? device : res
      end
    end

    # Given a device name to which we install the bootloader (loader_device),
    # get the name of the partition which should be activated.
    # Also return the device file name of the disk device that corresponds to
    # loader_device (i.e. where the corresponding MBR can be found).
    # @param [String] loader_device string the device to install bootloader to
    # @return a map $[ "mbr": string, "num": any]
    #  containing device (eg. "/dev/hda4"), disk (eg. "/dev/hda") and
    #  partition number (eg. 4)
    def partition_to_activate(loader_device)
      p_dev = Yast::Storage.GetDiskPartition(loader_device)
      num = Yast::BootCommon.myToInteger(p_dev["nr"])
      mbr_dev = p_dev["disk"] || ""

      # If loader_device is /dev/md* (which means bootloader is installed to
      # /dev/md*), return the info map for the first device in BIOS ID order
      # that underlies the soft-RAID and that has a BIOS ID (devices without
      # BIOS ID are excluded).
      # If no device is found in this way, return the info map for the
      # soft-RAID device ("/dev/md", "/dev/md[0-9]*").
      # FIXME: use ::storage to detect md devices, not by name!
      if loader_device.start_with?("/dev/md")
        base_device = first_base_device_to_boot(loader_device)
        if base_device
          return partition_to_activate(base_device)
        end
      end

      tm = Yast::Storage.GetTargetMap
      partitions = Yast::Ops.get_list(tm, [mbr_dev, "partitions"], [])
      # do not select swap and do not select BIOS grub partition
      # as it clear its special flags (bnc#894040)
      partitions.select! { |p| p["used_fs"] != :swap && p["fsid"] != Yast::Partitions.fsid_bios_grub }
      # (bnc # 337742) - Unable to boot the openSUSE (32 and 64 bits) after installation
      # if loader_device is disk Choose any partition which is not swap to
      # satisfy such bios (bnc#893449)
      if num == 0
        # strange, no partitions on our mbr device, we probably won't boot
        if partitions.empty?
          log.warn "no non-swap partitions for mbr device #{mbr_dev}"
          return {}
        end
        num = partitions.first["nr"]
        log.info "loader_device is disk device, so use its #{num} partition"
      end

      if num > 4
        Yast::Builtins.y2milestone("Bootloader partition type can be logical")
        partitions.each do |p|
          if p["type"] == :extended
            num = p["nr"] || num
            log.info "Using extended partition #{num} instead"
          end
        end
      end

      ret = {
        "num" => num,
        "mbr" => mbr_dev,
      }

      log.info "Partition for activating: #{ret}"
      ret
    end

    # Get a list of partitions to activate if user wants to activate
    # boot partition
    # @return a list of partitions to activate
    def grub_getPartitionsToActivate
      result = base_devices
      result = bootloader_devices if result.empty?

      result.map! { |partition| partition_to_activate(partition) }
      result.delete({})

      result.uniq
    end
  end
end
