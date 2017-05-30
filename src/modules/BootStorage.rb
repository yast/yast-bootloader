# encoding: utf-8

# File:
#      modules/BootStorage.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module includes specific functions for handling storage data.
#      The idea is handling all storage data necessary for bootloader
#      in one module.
#
# Authors:
#      Jozef Uhliarik <juhliarik@suse.cz>
#
#
#
#
require "yast"
require "storage"
require "y2storage"
require "bootloader/udev_mapping"
require "bootloader/exceptions"

module Yast
  class BootStorageClass < Module
    include Yast::Logger

    # Disk where to place MBR code. By default one with /boot partition
    # @return [Y2Storage::Disk]
    def mbr_disk
      detect_disks

      @mbr_disk
    end

    # Partition where lives /boot. If there is not separated /boot, / is used instead.
    # @return [Y2Storage::Partition]
    def boot_partition
      detect_disks

      @boot_partition
    end

    # Partition where / lives.
    # @return [Y2Storage::Partition]
    def root_partition
      detect_disks

      @root_partition
    end

    # Extended partition on same disk as /boot, nil if there is none
    # @return [Y2Storage::Partition, nil]
    def extended_partition
      detect_disks

      @extended_partition
    end

    def main
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "Mode"

      # FATE#305008: Failover boot configurations for md arrays with redundancy
      # list <string> includes physical disks used for md raid

      @md_physical_disks = []

      # Revision to recognize if cached values are still valid
      @storage_revision = nil
    end

    def storage_changed?
      @storage_revision != Y2Storage::StorageManager.instance.staging_revision
    end

    def staging
      Y2Storage::StorageManager.instance.y2storage_staging
    end

    def assign_mbr_disk_by_name(dev_name)
      @mbr_disk = staging.disks.find { |d| d.name == dev_name }
    end

    def gpt_boot_disk?
      require "bootloader/bootloader_factory"
      current_bl = ::Bootloader::BootloaderFactory.current

      # efi require gpt disk, so it is always one
      return true if current_bl.name == "grub2efi"
      # if bootloader do not know its location, then we do not care
      return false unless current_bl.respond_to?(:stage1)

      targets = current_bl.stage1.devices
      boot_disks = staging.disks.select { |d| targets.any? { |t| d.name_or_partition?(t) } }

      boot_disks.any? { |disk| disk.gpt? }
    end

    # Returns list of partitions and disks. Requests current partitioning from
    # yast2-storage and creates list of partition and disks usable for grub stage1
    def possible_locations_for_stage1
      devices = Storage.GetTargetMap

      all_disks = devices.keys

      disks_for_stage1 = all_disks.select do |d|
        [:CT_DISK, :CR_DMRAID].include?(devices[d]["type"])
      end

      partitions = []

      devices.each do |k, v|
        next unless all_disks.include?(k)

        partitions.concat(v["partitions"] || [])
      end

      partitions.delete_if do |p|
        p["delete"]
      end

      partitions.select! do |p|
        [:primary, :extended, :logical, :sw_raid].include?(p["type"]) &&
          (p["used_fs"] || p["detected_fs"]) != :xfs &&
          ["Linux native", "Extended", "Linux RAID", "MD RAID", "DM RAID"].include?(p["fstype"])
      end

      res = partitions.map { |p| p["device"] || "" }
      res.concat(disks_for_stage1)
      res.delete_if(&:empty?)

      res
    end

    # Get extended partition for given partition or disk
    def extended_partition_for(device)
      disk = staging.disks.find { |d| d.name_or_partition?(device) }
      return nil unless disk

      disk.partitions.find { |p| p.type.is?(:extended) }
    end

    # FIXME: merge with BootSupportCheck
    # Check if the bootloader can be installed at all with current configuration
    # @return [Boolean] true if it can
    def bootloader_installable?
      return true if Mode.config
      return true if !Arch.i386 && !Arch.x86_64

# storage-ng
# rubocop:disable Style/BlockComments
=begin
      # the only relevant is the partition holding the /boot filesystem
      detect_disks
      Builtins.y2milestone(
        "Boot partition device: %1",
        BootStorage.boot_partition.inspect
      )
      dev = Storage.GetDiskPartition(BootStorage.boot_partition.name)
      Builtins.y2milestone("Disk info: %1", dev)
      # MD, but not mirroring is OK
      # FIXME: type detection by name deprecated
      if Ops.get_string(dev, "disk", "") == "/dev/md"
        tm = Storage.GetTargetMap
        md = Ops.get_map(tm, "/dev/md", {})
        parts = Ops.get_list(md, "partitions", [])
        info = {}
        Builtins.foreach(parts) do |p|
          if Ops.get_string(p, "device", "") ==
              BootStorage.boot_partition.name
            info = deep_copy(p)
          end
        end
        if Builtins.tolower(Ops.get_string(info, "raid_type", "")) != "raid1"
          Builtins.y2milestone(
            "Cannot install bootloader on RAID (not mirror)"
          )
          return false
        end

      # EVMS
      # FIXME: type detection by name deprecated
      elsif Builtins.search(boot_partition.name, "/dev/evms/") == 0
        Builtins.y2milestone("Cannot install bootloader on EVMS")
        return false
      end
=end

      true
    end

    # Find the partition or disk for the filesystem mounted at mountpoint.
    #
    # Returns nil if no filesystem is found or the filesystem has no blkdevice
    # (e.g. NFS).
    #
    # If the filesystem is in a virtual device (like a LUKS or LVM volume), it
    # returns the (first) underlying partition or disk.
    def find_blk_device_at_mountpoint(mountpoint)
      fs = staging.filesystems.find { |f| f.mountpoint == mountpoint }
      return nil unless fs

      part = fs.ancestors.find { |a| a.is?(:partition) }
      return part if part

      disk = fs.ancestors.find { |a| a.is?(:disk) }
      return disk if disk

      nil
    end

    # Sets properly boot, root and mbr disk.
    # resets disk configuration. Clears cache from #detect_disks
    def reset_disks
      @boot_partition = @root_partition = @mbr_disk = @extended_partition = nil
    end

    def prep_partitions
      target_map = Storage.GetTargetMap

      partitions = target_map.reduce([]) do |parts, pair|
        parts.concat(pair[1]["partitions"] || [])
      end

      prep_partitions = partitions.select do |partition|
        [0x41, 0x108].include? partition["fsid"]
      end

      y2milestone "detected prep partitions #{prep_partitions.inspect}"
      prep_partitions.map { |p| p["device"] }
    end

    def disk_with_boot_partition
      disk = boot_partition.disk

      log.info "Boot device - disk: #{disk}"

      disk
    end

    def separated_boot?
      boot_partition != root_partition
    end

    # Get map of swap partitions
    # @return a map where key is partition name and value its size in KiB
    def available_swap_partitions
      ret = {}

      staging.filesystems.select { |f| f.type.is?(:swap) }.each do |swap|
        blk_device = swap.blk_devices[0]
        ret[blk_device.name] = blk_device.size / 1024
      end

      log.info "Available swap partitions: #{ret}"
      ret
    end

    def encrypted_boot?
      dev = boot_partition
      log.info "boot device = #{dev.inspect}"
      # check if on physical partition is any encryption
      result = dev.descendants.any? { |a| a.is?(:encryption) }

      log.info "encrypted_boot? = #{result}"

      result
    end

  private

    def detect_disks
      return if @root_partition # quit if already detected
      # While calling "yast clone_system" and while cloning bootloader
      # in the AutoYaST module, libStorage has to be set to "normal"
      # mode in order to read mountpoints correctly.
      # (bnc#950105)
      old_mode = Mode.mode
      if Mode.config
        Mode.SetMode("normal")
        log.info "Initialize libstorage in readonly mode" # bnc#942360
        Storage.InitLibstorage(true)
        StorageDevices.InitDone # Set StorageDevices flag disks_valid to true
      end

      # The AutoYaST config mode does access to the system.
      # bnc#942360

      @root_partition = find_blk_device_at_mountpoint("/")
      raise ::Bootloader::NoRoot, "Missing '/' mount point" unless @root_partition

      @boot_partition = find_blk_device_at_mountpoint("/boot")
      @boot_partition ||= @root_partition

      log.info "root partition #{root_partition.inspect}"
      log.info "boot partition #{boot_partition.inspect}"

      # get extended partition device (if exists)
      @extended_partition = extended_partition_for(boot_partition)

      @mbr_disk = disk_with_boot_partition

      @storage_revision = Y2Storage::StorageManager.instance.staging_revision

      Mode.SetMode(old_mode) if old_mode == "autoinst_config"
    end
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
