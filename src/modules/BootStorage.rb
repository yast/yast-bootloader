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

module Yast
  class BootStorageClass < Module
    include Yast::Logger
    using Y2Storage::Refinements::DevicegraphLists

    attr_accessor :mbr_disk

    def main
      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "Mode"

      # string sepresenting device name of /boot partition
      # same as RootPartitionDevice if no separate /boot partition
      @BootPartitionDevice = ""

      # string representing device name of / partition
      @RootPartitionDevice = ""

      # string representing device name of extended partition
      @ExtendedPartitionDevice = ""

      # FATE#305008: Failover boot configurations for md arrays with redundancy
      # list <string> includes physical disks used for md raid

      @md_physical_disks = []
    end

    def staging
      Y2Storage::StorageManager.instance.staging
    end

    def gpt_boot_disk?
      require "bootloader/bootloader_factory"
      current_bl = ::Bootloader::BootloaderFactory.current

      # efi require gpt disk, so it is always one
      return true if current_bl.name == "grub2efi"
      # if bootloader do not know its location, then we do not care
      return false unless current_bl.respond_to?(:stage1)

      targets = current_bl.stage1.devices
      boot_discs = targets.map { |d| Storage::Disk.find_by_name(staging, d) }
      boot_discs.any? do |d|
        d.partition_table? && d.partition_table.type == Storage::PtType_GPT
      end
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
      disk_list = staging.disks.with(name: device)
      disk_list ||= staging.partitions.with(name: device).disks
      return nil if disk_list.empty?

      part = disk_list.partitions.with(type: Storage::PartitionType_EXTENDED).first
      part ? part.name : nil
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
        BootStorage.BootPartitionDevice
      )
      dev = Storage.GetDiskPartition(BootStorage.BootPartitionDevice)
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
              BootStorage.BootPartitionDevice
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
      elsif Builtins.search(BootPartitionDevice(), "/dev/evms/") == 0
        Builtins.y2milestone("Cannot install bootloader on EVMS")
        return false
      end
=end

      true
    end

    # Find the blkdevice for the filesystem mounted at mountpoint. Returns nil
    # if no filesystem is found or the filesystem has no blkdevice (e.g. NFS).
    def find_blk_device_at_mountpoint(mountpoint)
      fses = Storage::Filesystem.find_by_mountpoint(staging, mountpoint)
      return nil if fses.empty?
      return nil if fses[0].blk_devices.empty?

      fses[0].blk_devices[0]
    end

    # Sets properly boot, root and mbr disk.
    def detect_disks
      return unless @RootPartitionDevice.empty? # quit if already detected
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

      root_blk_device = find_blk_device_at_mountpoint("/")

      boot_blk_device = find_blk_device_at_mountpoint("/boot")
      boot_blk_device = root_blk_device if !boot_blk_device

      # TODO: @RootPartitionDevice and @BootPartitionDevice should be the
      # BlkDevice object itself not its name

      @RootPartitionDevice = root_blk_device.name
      @BootPartitionDevice = boot_blk_device.name

      log.info "RootPartitionDevice #{@RootPartitionDevice}"
      log.info "BootPartitionDevice #{@BootPartitionDevice}"

      # get extended partition device (if exists)
      @ExtendedPartitionDevice = extended_partition_for(@BootPartitionDevice)

      @mbr_disk = disk_with_boot_partition

      Mode.SetMode(old_mode) if old_mode == "autoinst_config"
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
      boot_device = BootPartitionDevice()

      partition = Storage::Partition.find_by_name(staging, boot_device)
      partitionable = partition.partition_table.partitionable

      log.info "Boot device - disk: #{partitionable.name}"

      partitionable.name
    end

    def separated_boot?
      BootPartitionDevice() != RootPartitionDevice()
    end

    # Get map of swap partitions
    # @return a map where key is partition name and value its size in KiB
    def available_swap_partitions
      ret = {}

      Storage::Swap.all(staging).each do |swap|
        blk_device = swap.blk_devices[0]
        ret[blk_device.name] = blk_device.size / 1024
      end

      log.info "Available swap partitions: #{ret}"
      ret
    end

    # Build map with encrypted partitions (even indirectly)
    # @return map with encrypted partitions
    def crypto_devices
      cryptos = {}

# storage-ng
=begin
      tm = Yast::Storage.GetTargetMap || {}
      log.info "target map = #{tm}"

      # first, find the directly encrypted things
      # that is, target map has a 'crypt_device' key for it
      #
      # FIXME: can the device itself have a 'crypt_device' key?
      tm.each_value do |d|
        partitions = d["partitions"] || []
        partitions.each do |p|
          if p["crypt_device"]
            cryptos[p["device"]] = true
            cryptos[p["used_by_device"]] = true if p["used_by_device"]
          end
        end
      end

      log.info "crypto devices, step 1 = #{cryptos}"

      # second step: check if the encrypted things have itself partitions
      tm.each_value do |d|
        next if !cryptos[d["device"]]
        partitions = d["partitions"] || []
        partitions.each { |p| cryptos[p["device"]] = true }
      end
=end

      log.info "crypto devices, final = #{cryptos}"

      cryptos
    end

    def encrypted_boot?
      dev = BootPartitionDevice()
      log.info "boot device = #{dev}"
      result = !!crypto_devices[dev]

      log.info "encrypted_boot? = #{result}"

      result
    end

    publish :variable => :BootPartitionDevice, :type => "string"
    publish :variable => :RootPartitionDevice, :type => "string"
    publish :variable => :ExtendedPartitionDevice, :type => "string"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
