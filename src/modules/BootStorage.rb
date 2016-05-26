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
require "bootloader/udev_mapping"

module Yast
  class BootStorageClass < Module
    include Yast::Logger

    attr_accessor :mbr_disk

    def main
      textdomain "bootloader"

      Yast.import "Storage"
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

      @underlaying_devices_cache = {}
    end

    def gpt_boot_disk?
      require "bootloader/bootloader_factory"
      current_bl = ::Bootloader::BootloaderFactory.current

      # efi require gpt disk, so it is always one
      return true if current_bl.name == "grub2efi"
      # if bootloader do not know its location, then we do not care
      return false unless current_bl.respond_to?(:stage1)

      targets = current_bl.stage1.devices
      target_map = Yast::Storage.GetTargetMap
      boot_discs = targets.map { |d| Yast::Storage.GetDisk(target_map, d) }
      boot_discs.any? { |d| d["label"] == "gpt" }
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
      disk_partition = Yast::Storage.GetDiskPartition(device)
      return nil unless disk_partition["disk"]

      target_map = Yast::Storage.GetTargetMap
      disk_map = target_map[disk_partition["disk"]] || {}
      partitions = disk_map["partitions"] || []
      ext_part = partitions.find { |p| p["type"] == :extended }
      return nil unless ext_part

      ext_part["device"]
    end

    # returns device where dev physically lives, so where can be bootloader installed
    # it is main entry point when real stage 1 device is needed to get
    # @param dev [String] device for which detection should be done. Device here
    #   means any name  under /dev like "/dev/sda", "/dev/system/root" or "/dev/md-15".
    #   Such device have to be in kernel name, so no udev links.
    # @return [Array<String>] list of devices which is physically available
    #   and can be used for bootloader stage1. Devices is in kernel name.
    def underlaying_devices(dev)
      require "bootloader/stage1_device"
      ::Bootloader::Stage1Device.new(dev).real_devices
    end

    def find_mbr_disk
      # use the disk with boot partition
      mp = Storage.GetMountPoints
      boot_disk = Ops.get_string(
        mp,
        ["/boot", 2],
        Ops.get_string(mp, ["/", 2], "")
      )
      log.info "Disk with boot partition: #{boot_disk}, using for MBR"

      boot_disk
    end

    # FIXME: merge with BootSupportCheck
    # Check if the bootloader can be installed at all with current configuration
    # @return [Boolean] true if it can
    def bootloader_installable?
      return true if Mode.config
      return true if !Arch.i386 && !Arch.x86_64

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

      true
    end

    # Sets properly boot, root and mbr disk.
    def detect_disks
      # The AutoYaST config mode does access to the system.
      # bnc#942360
      return :ok if Mode.config

      mp = Storage.GetMountPoints

      mountdata_boot = mp["/boot"] || mp["/"]
      mountdata_root = mp["/"]

      log.info "mountPoints #{mp}"
      log.info "mountdata_boot #{mountdata_boot}"

      @RootPartitionDevice = mountdata_root ? mountdata_root.first || "" : ""
      raise "No mountpoint for / !!" if @RootPartitionDevice.empty?

      # if /boot changed, re-configure location
      @BootPartitionDevice = mountdata_boot.first

      # get extended partition device (if exists)
      @ExtendedPartitionDevice = extended_partition_for(@BootPartitionDevice)

      @mbr_disk = find_mbr_disk
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

      if boot_device.empty?
        log.error "BootPartitionDevice and RootPartitionDevice are empty"
        return boot_device
      end

      p_dev = Storage.GetDiskPartition(boot_device)

      boot_disk_device = p_dev["disk"]

      if boot_disk_device && !boot_disk_device.empty?
        log.info "Boot device - disk: #{boot_disk_device}"
        return boot_disk_device
      end

      log.error("Finding boot disk failed!")
      ""
    end

    # Get map of swap partitions
    # @return a map where key is partition name and value its size in KB
    def available_swap_partitions
      tm = Storage.GetTargetMap
      ret = {}
      tm.each_value do |v|
        partitions = v["partitions"] || []
        partitions.select! do |p|
          p["mount"] == "swap" && !p["delete"]
        end
        partitions.each do |s|
          # bnc#577127 - Encrypted swap is not properly set up as resume device
          if s["crypt_device"] && !s["crypt_device"].empty?
            dev = s["crypt_device"]
          else
            dev = s["device"]
          end
          ret[dev] = s["size_k"] || 0
        end
      end

      log.info "Available swap partitions: #{ret}"
      ret
    end

    # Build map with encrypted partitions (even indirectly)
    # @return map with encrypted partitions
    def crypto_devices
      cryptos = {}
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
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
