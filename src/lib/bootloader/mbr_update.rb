require "yast"

require "bootloader/boot_record_backup"
require "bootloader/stage1_device"
require "yast2/execute"
require "y2storage"

Yast.import "Arch"
Yast.import "PackageSystem"

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

    def devicegraph
      Y2Storage::StorageManager.instance.y2storage_staging
    end

    def mbr_disk
      @mbr_disk ||= Yast::BootStorage.mbr_disk.name
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
      mbr_storage_object = devicegraph.disks.find { |d| d.name == disk }
      raise "Cannot find in storage mbr disk #{disk}" unless mbr_storage_object
      mbr_storage_object.gpt?
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

    def can_activate_partition?(partition)
      # if primary partition on old DOS MBR table, GPT do not have such limit
      gpt_disk = partition.disk.gpt?

      !(Yast::Arch.ppc && gpt_disk) && (gpt_disk || partition.number <= 4)
    end

    def activate_partitions
      partitions_to_activate.each do |partition|
        next unless can_activate_partition?(partition)

        log.info "Activating partition #{partition.inspect}"
        # set corresponding flag only bnc#930903
        if gpt?(disk)
          # for legacy_boot storage_ng do not reset others, so lets
          # do it manually
          partition.siblings.select{ |d| d.is?(:partition) }.each { |p| p.legacy_boot = false }
          partition.legacy_boot = true
        else
          partition.boot = true
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
        dev = partition_to_activate(dev)
        dev ? dev.disk.name : mbr_disk
      end
      ret = [mbr_disk]
      # Add to disks only if part of raid on base devices lives on mbr_disk
      ret.concat(mbrs) if mbrs.include?(mbr_disk)
      # get only real disks
      ret = ret.each_with_object([]) do |disk, res|
        res.concat(::Bootloader::Stage1Device.new(disk).real_devices)
      end

      ret.uniq
    end

    def first_base_device_to_boot(md_device)
      md = ::Bootloader::Stage1Device.new(md_device)
      # storage-ng
      # No BIOS-ID support in libstorage-ng, so just return first one
      md.real_devices.first
# rubocop:disable Style/BlockComments
=begin
      md.real_devices.min_by { |device| bios_id_for(device) }
=end
      # rubocop:enable all
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
      return [] unless disk

      # do not select swap and do not select BIOS grub partition
      # as it clear its special flags (bnc#894040)
      disk.partitions.reject { |p| p.id.is?(:swap, :bios_boot) }
    end

    def extended_partition(partition)
      part = partition.siblings.find { |p| p.type.is?(:extended) }
      return nil unless part

      log.info "Using extended partition instead: #{part.inspect}"
      part
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
      partition = partition_of(real_device)

      # strange, no partitions on our mbr device, we probably won't boot
      if !partition
        log.warn "no non-swap partitions for mbr device #{mbr_dev.name}"
        return {}
      end

      if partition.type.is?(:logical)
        log.info "Bootloader partition type can be logical"
        partition = extended_partition(partition)
      end

      log.info "Partition for activating: #{partition.inspect}"
      partition
    end

    def partition_of(dev_name)
      device = Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name)
      if device.is?(:disk)
        mbr_dev = device
        # (bnc # 337742) - Unable to boot the openSUSE (32 and 64 bits) after installation
        # if loader_device is disk Choose any partition which is not swap to
        # satisfy such bios (bnc#893449)
        partition = activatable_partitions(mbr_dev).first
        log.info "loader_device is disk device, so use its partition #{partition.inspect}"
      else
        partition = device
      end
      partition
    end

    # Get a list of partitions to activate if user wants to activate
    # boot partition
    # @return a list of partitions to activate
    def partitions_to_activate
      result = boot_devices

      result.map! { |partition| partition_to_activate(partition) }
      result.uniq.compact
    end
  end
end
