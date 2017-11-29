require "yast"

require "bootloader/boot_record_backup"
require "bootloader/stage1_device"
require "yast2/execute"

Yast.import "Arch"
Yast.import "PackageSystem"
Yast.import "Partitions"

module Bootloader
  # this class place generic MBR wherever it is needed
  # and also mark needed partitions with boot flag and legacy_boot
  # FIXME: make it single responsibility class
  class MBRUpdate
    include Yast::Logger

    # Update contents of MBR (active partition and booting code)
    def run(stage1)
      log.info "Stage1: #{stage1.inspect}"
      @stage1 = stage1

      create_backups

      # Rewrite MBR with generic boot code only if we do not plan to install
      # there bootloader stage1
      install_generic_mbr if stage1.generic_mbr? && !stage1.mbr?

      activate_partitions if stage1.activate?
    end

  private

    def mbr_disk
      @mbr_disk ||= Yast::BootStorage.mbr_disk
    end

    def create_backups
      devices_to_backup = disks_to_rewrite + @stage1.devices + [mbr_disk]
      devices_to_backup.uniq!
      log.info "Creating backup of boot sectors of #{devices_to_backup}"
      backups = devices_to_backup.map do |d|
        ::Bootloader::BootRecordBackup.new(d)
      end
      backups.each(&:write)
    end

    def gpt?(disk)
      mbr_storage_object = target_map[disk]
      raise "Cannot find in storage mbr disk #{disk}" unless mbr_storage_object
      mbr_type = mbr_storage_object["label"]
      log.info "mbr type = #{mbr_type}"
      mbr_type == "gpt"
    end

    GPT_MBR = "/usr/share/syslinux/gptmbr.bin".freeze
    DOS_MBR = "/usr/share/syslinux/mbr.bin".freeze
    def generic_mbr_file_for(disk)
      @generic_mbr_file ||= gpt?(disk) ? GPT_MBR : DOS_MBR
    end

    def install_generic_mbr
      Yast::PackageSystem.Install("syslinux") unless Yast::Stage.initial

      disks_to_rewrite.each do |disk|
        log.info "Copying generic MBR code to #{disk}"
        # added fix 446 -> 440 for Vista booting problem bnc #396444
        command = ["/bin/dd", "bs=440", "count=1", "if=#{generic_mbr_file_for(disk)}", "of=#{disk}"]
        Yast::Execute.locally(*command)
      end
    end

    def set_parted_flag(disk, part_num, flag)
      # we need at first clear this flag to avoid multiple flags (bnc#848609)
      reset_flag(disk, flag)

      # and then set it
      command = ["/usr/sbin/parted", "-s", disk, "set", part_num, flag, "on"]
      Yast::Execute.locally(*command)
    end

    def reset_flag(disk, flag)
      command = ["/usr/sbin/parted", "-sm", disk, "print"]
      out = Yast::Execute.locally(*command, stdout: :capture)

      partitions = out.lines.select do |line|
        values = line.split(":")
        values[6] && values[6].match(/(?:\s|\A)#{flag}/)
      end
      partitions.map! { |line| line.split(":").first }

      partitions.each do |part_num|
        command = ["/usr/sbin/parted", "-s", disk, "set", part_num, flag, "off"]
        Yast::Execute.locally(*command)
      end
    end

    def can_activate_partition?(disk, num)
      # if primary partition on old DOS MBR table, GPT do not have such limit
      gpt_disk = gpt?(disk)

      !(Yast::Arch.ppc && gpt_disk) && (gpt_disk || num <= 4)
    end

    def activate_partitions
      partitions_to_activate.each do |m_activate|
        num = m_activate["num"]
        disk = m_activate["mbr"]
        if num.nil? || disk.nil?
          raise "INTERNAL ERROR: Data for partition to activate is invalid."
        end

        next unless can_activate_partition?(disk, num)

        log.info "Activating partition #{num} on #{disk}"
        # set corresponding flag only bnc#930903
        if gpt?(disk)
          set_parted_flag(disk, num, "legacy_boot")
        else
          set_parted_flag(disk, num, "boot")
        end
      end
    end

    def boot_devices
      @stage1.devices
    end

    # Get the list of MBR disks that should be rewritten by generic code
    # if user wants to do so
    # @return a list of device names to be rewritten
    def disks_to_rewrite
      # find the MBRs on the same disks as the devices underlying the boot
      # devices; if for any of the "underlying" or "base" devices no device
      # for acessing the MBR can be determined, include mbr_disk in the list
      mbrs = boot_devices.map do |dev|
        partition_to_activate(dev)["mbr"] || mbr_disk
      end
      log.info "found mbrs #{mbrs.inspect}"
      ret = [mbr_disk]
      # Add to disks only if part of raid on base devices lives on mbr_disk
      ret.concat(mbrs) if mbrs.include?(mbr_disk)
      log.info "disks to rewrite before real devices: #{ret.inspect}"
      # get only real disks
      ret = ret.each_with_object([]) do |disk, res|
        res.concat(::Bootloader::Stage1Device.new(disk).real_devices)
      end
      log.info "disks to rewrite after real devices: #{ret.inspect}"

      ret.compact.uniq
    end

    def first_base_device_to_boot(md_device)
      md = ::Bootloader::Stage1Device.new(md_device)
      md.real_devices.min_by { |device| bios_id_for(device) }
    end

    MAX_BIOS_ID = 1000
    def bios_id_for(device)
      disk = Yast::Storage.GetDiskPartition(device)["disk"]
      disk_info = target_map[disk]
      return MAX_BIOS_ID unless disk_info

      bios_id = disk_info["bios_id"]
      # prefer device without bios id over ones without disk info
      return MAX_BIOS_ID - 1  if !bios_id || bios_id !~ /0x[0-9a-fA-F]+/

      bios_id[2..-1].to_i(16) - 0x80
    end

    # List of partition for disk that can be used for setting boot flag
    def activatable_partitions(disk)
      partitions = target_map.fetch(disk, {}).fetch("partitions", [])
      # do not select swap and do not select BIOS grub partition
      # as it clear its special flags (bnc#894040)
      partitions.select do |p|
        p["used_fs"] != :swap && p["fsid"] != Yast::Partitions.fsid_bios_grub
      end
    end

    def extended_partition_num(disk)
      part = activatable_partitions(disk).find { |p| p["type"] == :extended }
      return nil unless part

      num = part["nr"]
      log.info "Using extended partition #{num} instead"
      num
    end

    # Given a device name to which we install the bootloader (loader_device),
    # gets back disk and partition number to activate. If empty Hash is returned
    # then no suitable partition to activate found.
    # @param [String] loader_device string the device to install bootloader to
    # @return a Hash `{ "mbr" => String, "num" => Integer }`
    #  containing disk (eg. "/dev/hda") and partition number (eg. 4)
    def partition_to_activate(loader_device)
      real_device = first_base_device_to_boot(loader_device)
      log.info "real devices for #{loader_device} is #{real_device}"

      p_dev = Yast::Storage.GetDiskPartition(real_device)
      num = p_dev["nr"].to_i
      mbr_dev = p_dev["disk"]
      raise "Invalid loader device #{loader_device}" unless mbr_dev

      # (bnc # 337742) - Unable to boot the openSUSE (32 and 64 bits) after installation
      # if loader_device is disk Choose any partition which is not swap to
      # satisfy such bios (bnc#893449)
      if num == 0
        partition = activatable_partitions(mbr_dev).first
        # strange, no partitions on our mbr device, we probably won't boot
        if !partition
          log.warn "no non-swap partitions for mbr device #{mbr_dev}"
          return {}
        end
        log.info "loader_device is disk device, so use its partition #{partition.inspect}"
        num = partition["nr"] or return {}
      end

      if num > 4
        log.info "Bootloader partition type can be logical"
        num = extended_partition_num(mbr_dev) || num
      end

      ret = {
        "num" => num,
        "mbr" => mbr_dev
      }

      log.info "Partition for activating: #{ret}"
      ret
    end

    # Get a list of partitions to activate if user wants to activate
    # boot partition
    # @return a list of partitions to activate
    def partitions_to_activate
      result = boot_devices

      result.map! { |partition| partition_to_activate(partition) }
      result.delete({})

      result.uniq
    end

    def target_map
      @target_map ||= Yast::Storage.GetTargetMap
    end
  end
end
