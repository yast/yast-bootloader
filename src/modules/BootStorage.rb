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
      ret = false

      # fix for problem with unintialized storage library in AutoYaST mode
      # bnc #464090
      if Mode.config && !@storage_initialized
        @storage_initialized = true
        Builtins.y2milestone("Init storage library in yast2-bootloader")
        Storage.InitLibstorage(true)
      end
      if @disk_change_time_checkCallingDiskInfo != Storage.GetTargetChangeTime ||
          Ops.less_than(Builtins.size(@partinfo), 1)
        # save last change time from storage
        @disk_change_time_checkCallingDiskInfo = Storage.GetTargetChangeTime
        Builtins.y2milestone(
          "disk was changed by storage or partinfo is empty: %1",
          Builtins.size(@partinfo)
        )
        Builtins.y2milestone(
          "generate partinfo, md_info, mountpoints and multipath_mapping"
        )
        ret = true
      else
        ret = false
        Builtins.y2milestone(
          "Skip genarating partinfo, md_info, mountpoints and multipath_mapping"
        )
      end

      ret
    end

    # Function init data for perl-Bootloader about disk
    # It means fullfil md_info, multipath_mapping, partinfo
    # and mountpoints

    def InitDiskInfo
      if checkCallingDiskInfo
        # delete variables for perl-Bootloader
        @md_info = {}

        tm = Storage.GetTargetMap

        @multipath_mapping = mapRealDevicesToMultipath
        @mountpoints = Builtins.mapmap(Storage.GetMountPoints) do |k, v|
          # detect all raid1 md devices and mark them in md_info
          device = Ops.get(v, 0)
          if Ops.get_string(v, 3, "") == "raid1"
            Ops.set(@md_info, Convert.to_string(device), [])
          end
          { k => device }
        end
        @mountpoints = Builtins.filter(@mountpoints) do |k, v|
          tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
          tmp_sz = Builtins.size(tmpdir)
          Ops.is_string?(v) && Builtins.substring(k, 0, tmp_sz) != tmpdir
        end

        Builtins.y2milestone("Detected mountpoints: %1", @mountpoints)

        pi = Builtins.maplist(tm) do |disk, info|
          next [] if Ops.get_symbol(info, "type", :CT_UNKNOWN) == :CT_LVM
          next [] if Ops.get_symbol(info, "type", :CT_UNKNOWN) == :CT_EVMS
          partitions = Ops.get_list(info, "partitions", [])
          parts = Builtins.maplist(
            Convert.convert(partitions, :from => "list", :to => "list <map>")
          ) do |p|
            raid = ""
            if Ops.get_symbol(p, "used_by_type", :UB_NONE) == :UB_MD
              raid = Ops.get_string(p, "used_by_device", "")
            end
            device = Ops.get_string(p, "device", "")
            # We only pass along RAID1 devices as all other causes
            # severe breakage in the bootloader stack
            if raid != ""
              if Builtins.haskey(@md_info, raid)
                members = Ops.get(@md_info, raid, [])
                members = Builtins.add(members, device)
                Ops.set(@md_info, raid, members)
              end
            end
            nr = Ops.get(p, "nr")
            nr = 0 if nr == nil
            nr_str = Builtins.sformat("%1", nr)
            [
              device,
              disk,
              nr_str,
              Builtins.tostring(Ops.get_integer(p, "fsid", 0)),
              Ops.get_string(p, "fstype", "unknown"),
              Builtins.tostring(Ops.get(p, "type")),
              Builtins.tostring(Ops.get_integer(p, ["region", 0], 0)),
              Builtins.tostring(Ops.get_integer(p, ["region", 1], 0))
            ]
          end
          deep_copy(parts)
        end
        @partinfo = Builtins.flatten(pi)
        @partinfo = Builtins.filter(@partinfo) { |p| p != nil && p != [] }
        partinfo_mountby = []
        # adding moundby (by-id) via user preference
        Builtins.foreach(@partinfo) do |partition|
          tmp = []
          mount_by = ::Bootloader::UdevMapping.to_mountby_device(
            Builtins.tostring(Ops.get_string(partition, 0, ""))
          )
          if mount_by != Builtins.tostring(Ops.get_string(partition, 0, ""))
            tmp = Builtins.add(partition, mount_by)
          else
            tmp = deep_copy(partition)
          end
          partinfo_mountby = Builtins.add(partinfo_mountby, tmp)
        end
        # y2milestone("added mountby: %1", partinfo_mountby);

        @partinfo = deep_copy(partinfo_mountby)
      end

      nil
    end


    # Generate device map proposal, store it in internal variables.
    def ProposeDeviceMap
      @device_map = ::Bootloader::DeviceMap.new
      @multipath_mapping = {}

      if Mode.config
        log.info("Skipping device map proposing in Config mode")
        return
      end

      @device_map.propose
      log.info("Detected device mapping: #{@device_map}")

      @multipath_mapping = mapRealDevicesToMultipath
      log.info("Detected multipath mapping: #{@multipath_mapping}")
    end

    # Get the order of disks according to BIOS mapping
    # @return a list of all disks in the order BIOS sees them
    def DisksOrder
      @device_map.propose if @device_map.empty?

      @device_map.disks_order
    end

    # Function remap device map to device name (/dev/sda)
    # or to label (ufo_disk)
    # @param map<string,string> device map
    # @return [Hash{String => String}] new device map

    def remapDeviceMap
      @device_map.remapped_hash
    end

    # Returns list of partitions. Requests current partitioning from
    # yast2-storage and creates list of partition usable for boot partition
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

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Check if devices has same partition number and if they are from different disks
    #
    # @param list <string> list of devices
    # @return [Boolean] true on success
    def checkDifferentDisks(devices)
      devices = deep_copy(devices)
      ret = false
      disks = []
      no_partition = ""
      Builtins.foreach(devices) do |dev|
        p_dev = Storage.GetDiskPartition(dev)
        if !Builtins.contains(disks, Ops.get_string(p_dev, "disk", ""))
          disks = Builtins.add(disks, Ops.get_string(p_dev, "disk", ""))
        else
          Builtins.y2milestone(
            "Same disk for md array -> disable synchronize md arrays"
          )
          raise Break
        end
        # add disk from partition to md_physical_disks
        if !Builtins.contains(
            @md_physical_disks,
            Ops.get_string(p_dev, "disk", "")
          )
          @md_physical_disks = Builtins.add(
            @md_physical_disks,
            Ops.get_string(p_dev, "disk", "")
          )
        end
        no_p = Builtins.tostring(Ops.get(p_dev, "nr"))
        if no_p == ""
          Builtins.y2error(
            "Wrong number of partition: %1 from Storage::GetDiskPartition: %2",
            dev,
            p_dev
          )
          raise Break
        end
        if no_partition == ""
          no_partition = no_p
        elsif no_partition == no_p
          ret = true
        else
          Builtins.y2milestone(
            "Different number of partitions -> disable synchronize md arrays"
          )
        end
      end

      Builtins.y2milestone(
        "checkDifferentDisks for devices: %1 return: %2",
        devices,
        ret
      )

      ret
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Check if device are build from 2 partitions with same number but from different disks
    #
    # @param [Hash{String => map}] tm taregte map from storage
    # @param [String] device (md device)
    # @return true if device is from 2 partisions with same number and different disks
    def checkMDDevices(tm, device)
      tm = deep_copy(tm)
      ret = false
      tm_dm = Convert.convert(
        Ops.get(tm, "/dev/md", {}),
        :from => "map",
        :to   => "map <string, any>"
      )

      @md_physical_disks = []
      # find partitions in target map
      Builtins.foreach(Ops.get_list(tm_dm, "partitions", [])) do |p|
        if Ops.get_string(p, "device", "") == device
          if Ops.get_string(p, "raid_type", "") == "raid1"
            p_devices = Ops.get_list(p, "devices", [])
            if Builtins.size(p_devices) == 2
              ret = checkDifferentDisks(p_devices)
            else
              Builtins.y2milestone(
                "Device: %1 doesn't contain 2 partitions: %2",
                device,
                p_devices
              )
            end
          else
            Builtins.y2milestone(
              "Device: %1 is not on raid1: %2",
              device,
              Ops.get_string(p, "raid_type", "")
            )
          end
        end
      end

      if Builtins.size(@md_physical_disks) != 2 ||
          Builtins.contains(@md_physical_disks, "")
        Builtins.y2milestone(
          "device: %1 is based on md_physical_disks: %2 is not valid for enable redundancy",
          device,
          @md_physical_disks
        )
      end

      if ret
        Builtins.y2milestone(
          "device: %1 is based on md_physical_disks: %2 is valid for enable redundancy",
          device,
          @md_physical_disks
        )
      end

      ret
    end

    def can_boot_from_partition
      tm = Storage.GetTargetMap
      partition = @BootPartitionDevice || @RootPartitionDevice

      part = Storage.GetPartition(tm, partition)

      if !part
        Builtins.y2error("cannot find partition #{partition}")
        return false
      end

      fs = part["used_fs"]
      Builtins.y2milestone("FS for boot partition #{fs}")

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

      if !Builtins.haskey(tm, "/dev/md")
        Builtins.y2milestone("Doesn't include md raid")
        return ret
      end
      boot_devices = []
      if @BootPartitionDevice != "" && @BootPartitionDevice != nil
        boot_devices = Builtins.add(boot_devices, @BootPartitionDevice)
      end
      if @BootPartitionDevice != @RootPartitionDevice &&
          @RootPartitionDevice != "" &&
          @BootPartitionDevice != nil
        boot_devices = Builtins.add(boot_devices, @RootPartitionDevice)
      end
      if @ExtendedPartitionDevice != "" && @ExtendedPartitionDevice != nil
        boot_devices = Builtins.add(boot_devices, @ExtendedPartitionDevice)
      end

      Builtins.y2milestone(
        "Devices for analyse of redundacy md array: %1",
        boot_devices
      )
      Builtins.foreach(boot_devices) do |dev|
        ret = checkMDDevices(tm, dev)
        if !ret
          Builtins.y2milestone("Skip enable redundancy of md arrays")
          raise Break
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
      Builtins.y2milestone("Partitions building %1: %2", md_device, ret)

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
        if disk_meta
          if disk_meta["lvm2"]
            devices = (disk_meta["devices"] || []) + (disk_meta["devices_add"] || [])
            disks = devices.map { |d| real_disks_for_partition(d) }
            ret.concat(disks.flatten)
          else
            ret << disk
          end
        end
        ret
      end

      res.uniq
    end

    publish :variable => :multipath_mapping, :type => "map <string, string>"
    publish :variable => :mountpoints, :type => "map <string, any>"
    publish :variable => :partinfo, :type => "list <list>"
    publish :variable => :md_info, :type => "map <string, list <string>>"
    publish :variable => :BootPartitionDevice, :type => "string"
    publish :variable => :RootPartitionDevice, :type => "string"
    publish :variable => :ExtendedPartitionDevice, :type => "string"
    publish :function => :InitDiskInfo, :type => "void ()"
    publish :function => :ProposeDeviceMap, :type => "void ()"
    publish :function => :DisksOrder, :type => "list <string> ()"
    publish :function => :remapDeviceMap, :type => "map <string, string> ()"
    publish :function => :getPartitionList, :type => "list <string> (symbol, string)"
    publish :function => :addMDSettingsToGlobals, :type => "string ()"
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
