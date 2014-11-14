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
require "bootloader/device_map"
require "bootloader/udev_mapping"

module Yast
  class BootStorageClass < Module
    include Yast::Logger

    attr_accessor :device_map

    def main

      textdomain "bootloader"

      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Arch"
      Yast.import "Mode"


      # Saved change time from target map - only for checkCallingDiskInfo()
      @disk_change_time_checkCallingDiskInfo = nil

      # Storage locked
      @storage_initialized = false

      # device mapping between real devices and multipath
      @multipath_mapping = {}

      # mountpoints for perl-Bootloader
      @mountpoints = {}


      # list of all partitions for perl-Bootloader
      @partinfo = []

      # information about MD arrays for perl-Bootloader
      @md_info = {}

      # device mapping between Linux and firmware
      @device_map = ::Bootloader::DeviceMap.new

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

    # bnc #447591, 438243, 448110 multipath wrong device map
    # Function maps real devices to multipath e.g.
    # "/dev/sda/" : "/dev/mapper/SATA_ST3120813AS_3LS0CD7M"
    #
    # @return [Hash{String => String}] mapping real disk to multipath

    # FIXME grub only

    def mapRealDevicesToMultipath
      ret = {}
      tm = Storage.GetTargetMap
      tm.each do |disk, disk_info|
        next unless disk_info["type"] != :CT_DMMULTIPATH

        devices = disk_info["devices"] || []
        devices.each { |d| ret[d] = disk }
      end

      ret
    end




    # Check if function was called or storage change
    # partitionig of disk. It is usefull fo using cached data
    # about disk. Data is send to perl-Bootloader and it includes
    # info about partitions, multi path and md-raid
    #
    # @return false if it is posible use cached data

    def checkCallingDiskInfo
      # fix for problem with unintialized storage library in AutoYaST mode
      # bnc #464090
      if Mode.config && !@storage_initialized
        @storage_initialized = true
        log.info "Init storage library in yast2-bootloader"
        Storage.InitLibstorage(true)
      end
      if @disk_change_time_checkCallingDiskInfo != Storage.GetTargetChangeTime ||
          @partinfo.empty?
        # save last change time from storage
        @disk_change_time_checkCallingDiskInfo = Storage.GetTargetChangeTime
        log.info "disk was changed by storage or partinfo is empty"
        log.info "generate partinfo, md_info, mountpoints and multipath_mapping"
        return true
      else
        log.info "Skip genarating partinfo, md_info, mountpoints and multipath_mapping"
        return false
      end
    end

    # Function init data for perl-Bootloader about disk
    # It means fullfil md_info, multipath_mapping, partinfo
    # and mountpoints

    def InitDiskInfo
      return unless checkCallingDiskInfo

      # delete variables for perl-Bootloader
      @md_info = {}

      tm = Storage.GetTargetMap

      @multipath_mapping = mapRealDevicesToMultipath
      @mountpoints = Builtins.mapmap(Storage.GetMountPoints) do |k, v|
        # detect all raid1 md devices and mark them in md_info
        device = v[0]
        @md_info[device] = [] if v[3] == "raid1"
        { k => device }
      end
      # filter out temporary mount points from installation

      tmpdir = SCR.Read(path(".target.tmpdir"))
      @mountpoints = Builtins.filter(@mountpoints) do |k, v|
        v.is_a?(::String) && !k.start_with?(tmpdir)
      end

      log.info "Detected mountpoints: #{@mountpoints}"

      @partinfo = tm.reduce([]) do |res, i|
        disk, info = i
        next res if [:CT_LVM, :CT_EVMS].include?(info["type"])
        partitions = info["partitions"]
        parts = partitions.map do |p|
          raid = nil
          if p["used_by_type"] == :UB_MD
            raid = p["used_by_device"]
          end
          device = p["device"] || ""
          # We only pass along RAID1 devices as all other causes
          # severe breakage in the bootloader stack
          if raid && @md_info.include?(raid)
            @md_info[raid] << device
          end
          nr = (p["nr"] || 0).to_s
          region = p.fetch("region", [])
          [
            device,
            disk,
            nr,
            p["fsid"].to_i.to_s,
            p["fstype"] || "unknown",
            p["type"] || "nil",
            (region[0] || 0).to_s,
            (region[1] || 0).to_s,
            ::Bootloader::UdevMapping.to_mountby_device(device)
          ]
        end
        res.concat(parts)
      end
    end


    # Get the order of disks according to BIOS mapping
    # @return a list of all disks in the order BIOS sees them
    def DisksOrder
      @device_map.propose if @device_map.empty?

      @device_map.disks_order
    end


    # Returns list of partitions and disks. Requests current partitioning from
    # yast2-storage and creates list of partition and disks usable for grub stage1
    def possible_locations_for_stage1
      devices = Storage.GetTargetMap

      all_disks = devices.keys
      # Devices which is not in device map cannot be used to boot
      all_disks.select! { |d| device_map.contain_disk?(d) }

      disks_for_stage1 = all_disks.select do |d|
        [:CT_DISK, :CR_DMRAID].include?(devices[d]["type"])
      end

      partitions = []

      devices.each do |k, v|
        if all_disks.include?(k)
          partitions.concat(v["partitions"] || [])
        end
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

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Check if devices has same partition number and if they are from different disks
    #
    # @param list <string> list of devices
    # @return [Boolean] true on success
    def checkDifferentDisks(devices)
      disks = []
      no_partition = ""
      devices.each do |dev|
        p_dev = Storage.GetDiskPartition(dev)
        disk = p_dev["disk"]
        if disks.include?(disk)
          log.info "Same disk for md array -> disable synchronize md arrays"
          return false
        else
          disks <<  disk
        end
        # add disk from partition to md_physical_disks
        @md_physical_disks << disk unless @md_physical_disks.include?(disk)

        no_p = p_dev["nr"].to_s
        if no_p == ""
          log.error "Wrong number of partition: #{dev} from Storage::GetDiskPartition: #{p_dev}"
          return false
        end
        if no_partition == ""
          no_partition = no_p
        elsif no_partition != no_p
          log.info "Different number of partitions -> disable synchronize md arrays"
          return false
        end
      end

      true
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Check if device are build from 2 partitions with same number but from different disks
    #
    # @param [Hash{String => map}] tm taregte map from storage
    # @param [String] device (md device)
    # @return true if device is from 2 partisions with same number and different disks
    def checkMDDevices(tm, device)
      ret = false
      tm_dm = tm["/dev/md"] || {}

      # find partitions in target map
      (tm_dm["partitions"] || []).each do |p|
        next unless p["device"] == device

        if p["raid_type"] == "raid1"
          p_devices = p["devices"] || []
          if p_devices.size == 2 # TODO why only 2? it do not make sense
            ret = checkDifferentDisks(p_devices)
          else
            log.info "Device: #{device} doesn't contain 2 partitions: #{p_devices}"
          end
        else
          log.info "Device: #{device} is not on raid1: #{p["raid_type"]}"
        end
      end

      log.info "device: #{device} is based on md_physical_disks: #{@md_physical_disks}"\
        "is #{ ret ? "valid" : "invalid" } for enable redundancy"

      ret
    end

    def can_boot_from_partition
      tm = Storage.GetTargetMap
      partition = @BootPartitionDevice || @RootPartitionDevice

      part = Storage.GetPartition(tm, partition)

      if !part
        log.error "cannot find partition #{partition}"
        return false
      end

      fs = part["used_fs"]
      log.info "FS for boot partition #{fs}"

      # cannot install stage one to xfs as it doesn't have reserved space (bnc#884255)
      return fs != :xfs
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Function check partitions and set redundancy available if
    # partitioning of disk allows it.
    # It means if md array is based on 2 partitions with same number but 2 different disks
    # E.g. /dev/md0 is from /dev/sda1 and /dev/sb1 and /dev/md0 is "/"
    # There is possible only boot from MBR (GRUB not generic boot code)
    #
    # @return [Boolean] true on success

    def checkMDSettings
      ret = false
      tm = Storage.GetTargetMap

      if !tm["/dev/md"]
        log.info "Doesn't include md raid"
        return ret
      end
      boot_devices = []
      boot_devices << @BootPartitionDevice
      if @BootPartitionDevice != @RootPartitionDevice
        boot_devices << @RootPartitionDevice
      end
      boot_devices << @ExtendedPartitionDevice
      boot_devices.delete_if { |d| d.nil? || d.empty? }

      log.info "Devices for analyse of redundacy md array: #{boot_devices}"

      boot_devices.each do |dev|
        ret = checkMDDevices(tm, dev)
        if !ret
          log.info "Skip enable redundancy of md arrays"
          break
        end
      end

      ret
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Function prapare disks for synchronizing of md array
    #
    # @return [String] includes disks separatet by ","

    def addMDSettingsToGlobals
      ret = ""

      ret = Builtins.mergestring(@md_physical_disks, ",") if checkMDSettings
      ret
    end

    # Converts the md device to the list of devices building it
    # @param [String] md_device string md device
    # @return a map of devices from device name to BIOS ID or empty hash if
    #   not detected) building the md device
    def Md2Partitions(md_device)
      ret = {}
      tm = Storage.GetTargetMap
      tm.each_pair do |disk, descr|
        bios_id = (descr["bios_id"] || 256).to_i # maximum + 1 (means: no bios_id found)
        partitions = descr["partitions"] || []
        partitions.each do |partition|
          if partition["used_by_device"] == md_device
            ret[partition["device"]] = bios_id
          end
        end
      end
      log.info "Partitions building #{md_device}: #{ret}"

      ret
    end

    # returns disk names where partition lives
    def real_disks_for_partition(partition)
      # FIXME handle somehow if disk are in logical raid
      partitions = Md2Partitions(partition).keys
      partitions = [partition] if partitions.empty?
      res = partitions.map do |partition|
        Storage.GetDiskPartition(partition)["disk"]
      end
      res.uniq!
      # handle LVM disks
      tm = Storage.GetTargetMap
      res = res.reduce([]) do |ret, disk|
        disk_meta = tm[disk]
        next ret unless disk_meta

        if disk_meta["lvm2"]
          devices = (disk_meta["devices"] || []) + (disk_meta["devices_add"] || [])
          disks = devices.map { |d| real_disks_for_partition(d) }
          ret.concat(disks.flatten)
        else
          ret << disk
        end
        ret
      end

      res.uniq
    end

    # Sets properly boot, root and mbr disk.
    # @return true if proposal need to be reconfigured
    def detect_disks
      mp = Storage.GetMountPoints

      mountdata_boot = mp["/boot"] || mp["/"]
      mountdata_root = mp["/"]

      log.info "mountPoints #{mp}"
      log.info "mountdata_boot #{mountdata_boot}"

      self.RootPartitionDevice = mountdata_root.first || ""
      raise "No mountpoint for / !!" if BootStorage.RootPartitionDevice.empty?

      # if /boot changed, re-configure location
      self.BootPartitionDevice = mountdata_boot.first

      # get extended partition device (if exists)
      self.ExtendedPartitionDevice = extended_partition_for(BootPartitionDevice())

      if BootCommon.mbrDisk == "" || BootCommon.mbrDisk == nil
        # mbr detection.
        BootCommon.mbrDisk = BootCommon.FindMBRDisk
      end

      # if no bootloader devices have been set up, or any of the set up
      # bootloader devices have become unavailable, then re-propose the
      # bootloader location.
      bldevs = BootCommon.GetBootloaderDevices

      return true if bldevs.empty?

      all_boot_partitions = BootStorage.possible_locations_for_stage1
      bldevs.any? do |dev|
        !all_boot_partitions.include?(dev)
      end
    end

    publish :variable => :multipath_mapping, :type => "map <string, string>"
    publish :variable => :mountpoints, :type => "map <string, any>"
    publish :variable => :partinfo, :type => "list <list>"
    publish :variable => :md_info, :type => "map <string, list <string>>"
    publish :variable => :BootPartitionDevice, :type => "string"
    publish :variable => :RootPartitionDevice, :type => "string"
    publish :variable => :ExtendedPartitionDevice, :type => "string"
    publish :function => :InitDiskInfo, :type => "void ()"
    publish :function => :DisksOrder, :type => "list <string> ()"
    publish :function => :addMDSettingsToGlobals, :type => "string ()"
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
