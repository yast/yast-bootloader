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

module Yast
  class BootStorageClass < Module
    def main

      textdomain "bootloader"

      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Arch"
      Yast.import "Mode"


      # Saved change time from target map - only for MapAllPartitions()
      @disk_change_time_InitBootloader = nil

      # Saved change time from target map - only for MapAllPartitions()

      @disk_change_time_MapAllPartitions = nil

      # Saved change time from target map - only for checkCallingDiskInfo()

      @disk_change_time_checkCallingDiskInfo = nil

      # bnc #468922 - problem with longtime running the parsing a huge number of disks
      # map<string,map> the map of all partitions with info about it ->
      # necessary for Dev2MountByDev() in routines/misc.ycp
      @all_partitions = {}

      # bnc #468922 - problem with longtime running the parsing a huge number of disks
      # map<string,map> target map try to minimalize calling Storage::GetTargetMap()
      #
      @target_map = {}


      # mapping all devices udev-name to kernel name
      # importnat for init fucntion of perl-Bootloader
      @all_devices = {}


      # Storage locked
      @storage_initialized = false


      # device mapping between real devices and multipath
      @multipath_mapping = {}


      # FIXME: it is ugly hack because y2-storage doesn't known
      # to indicate that it finish (create partitions) proposed partitioning of disk in installation
      # bnc#594482 - grub config not using uuid
      # Indicate if storage already finish partitioning of disk
      # if some partition includes any keyword "create"
      # the value is the first found partition with flag "create" e.g. /dev/sda2
      # empty string means all partitions are created
      @proposed_partition = ""

      # bnc#594482 - grub config not using uuid
      # 0 - if all devices in variable all_devices are created.
      # 1 - if partition with flag "create" was found in MapDevices()
      # 2 - if proposed_partition was created or flag "create" was deleted
      # by y2-storage. the value is set in CheckProposedPartition ()
      @all_devices_created = 0

      # bnc#594482 - grub config not using uuid
      # 0 - if all devices in variable all_partitions and all_disks are created
      # 1 - if partition with flag "create" was found in MapDevices()
      # 2 - if proposed_partition was created or flag "create" was deleted
      # by y2-storage. the value is set in CheckProposedPartition ()
      @all_partitions_created = 0

      # mountpoints for perl-Bootloader

      @mountpoints = {}


      # list of all partitions for perl-Bootloader

      @partinfo = []

      # information about MD arrays for perl-Bootloader
      @md_info = {}


      # Flag indicates that bios_id_missing in disk
      # true if missing false if at least one disk has bios_id
      @bois_id_missing = true

      # device mapping between Linux and firmware
      @device_mapping = {}



      # string sepresenting device name of /boot partition
      # same as RootPartitionDevice if no separate /boot partition
      @BootPartitionDevice = ""


      # string representing device name of / partition
      @RootPartitionDevice = ""

      # string representing device name of extended partition
      @ExtendedPartitionDevice = ""

      # string representing device name of PReP partition
      @PRePPartitionDevice = ""

      # list of installed floppy devices
      @floppy_devices = nil


      # FATE#305008: Failover boot configurations for md arrays with redundancy
      # list <string> includes physical disks used for md raid

      @md_physical_disks = []
    end

    # FATE #302219 - Use and choose persistent device names for disk devices
    # Function prepare maps with mapping disks and partitions by uuid, id, path
    # and label.
    #
    def MapDevices
      dev_by_something = ""
      devices = Storage.GetTargetMap
      Builtins.foreach(devices) do |k, v|
        # map disk by uuid
        if Ops.get(v, "uuid") != "" && Ops.get(v, "uuid") != nil
          dev_by_something = Ops.add(
            "/dev/disk/by-uuid/",
            Ops.get_string(v, "uuid", "")
          )
          Ops.set(@all_devices, dev_by_something, k)
        end
        # map disk by path
        if Ops.get(v, "path") != "" && Ops.get(v, "path") != nil
          dev_by_something = Ops.add(
            "/dev/disk/by-path/",
            Ops.get_string(v, "path", "")
          )
          Ops.set(@all_devices, dev_by_something, k)
        end
        # map disk by id
        if Ops.get(v, "udev_id") != nil && Ops.get(v, ["udev_id", 0]) != ""
          dev_by_something = Ops.add(
            "/dev/disk/by-id/",
            Ops.get_string(v, ["udev_id", 0], "")
          )
          Ops.set(@all_devices, dev_by_something, k)
          # bnc #534905 - yast2 bootloader 2.18.15-1.1 damages /etc/grub.conf
          if Builtins.size(Ops.get_list(v, "udev_id", [])) == 2
            dev_by_something = Ops.add(
              "/dev/disk/by-id/",
              Ops.get_string(v, ["udev_id", 1], "")
            )
            Ops.set(@all_devices, dev_by_something, k)
          end
        end
        # map partitions from disk...
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          # bnc#594482 - grub config not using uuid
          # if there is "not created" partition and flag for "it" is not set
          if Ops.get(p, "create") == true && Mode.installation
            if @proposed_partition == ""
              @proposed_partition = Ops.get_string(p, "device", "")
            end
            @all_devices_created = 1
          end
          # map partition by uuid
          # watch out for fake uuids (shorter than 9 chars)
          if Ops.greater_than(Builtins.size(Ops.get_string(p, "uuid", "")), 8)
            dev_by_something = Ops.add(
              "/dev/disk/by-uuid/",
              Ops.get_string(p, "uuid", "")
            )
            Ops.set(
              @all_devices,
              dev_by_something,
              Ops.get_string(p, "device", "")
            )
          end
          # map partition by path
          if Ops.get(p, "path") != "" && Ops.get(p, "path") != nil
            dev_by_something = Ops.add(
              "/dev/disk/by-path/",
              Ops.get_string(p, "path", "")
            )
            Ops.set(
              @all_devices,
              dev_by_something,
              Ops.get_string(p, "device", "")
            )
          end
          # map partition by label
          if Ops.get(p, "label") != "" && Ops.get(p, "label") != nil
            dev_by_something = Ops.add(
              "/dev/disk/by-label/",
              Ops.get_string(p, "label", "")
            )
            Ops.set(
              @all_devices,
              dev_by_something,
              Ops.get_string(p, "device", "")
            )
          end
          # map disk by id
          if Ops.get(p, "udev_id") != nil && Ops.get(p, ["udev_id", 0]) != ""
            dev_by_something = Ops.add(
              "/dev/disk/by-id/",
              Ops.get_string(p, ["udev_id", 0], "")
            )
            Ops.set(
              @all_devices,
              dev_by_something,
              Ops.get_string(p, "device", "")
            )
            # bnc #534905 - yast2 bootloader 2.18.15-1.1 damages /etc/grub.conf
            if Builtins.size(Ops.get_list(p, "udev_id", [])) == 2
              dev_by_something = Ops.add(
                "/dev/disk/by-id/",
                Ops.get_string(p, ["udev_id", 1], "")
              )
              Ops.set(
                @all_devices,
                dev_by_something,
                Ops.get_string(p, "device", "")
              )
            end
          end
        end # end of foreach (map p, (list<map>)(v["partitions"]:[]),
      end # end of foreach (string k, map v, devices,
      if Mode.installation && @all_devices_created == 2
        @all_devices_created = 0
        Builtins.y2milestone("set status for all_devices to \"created\"")
      end
      Builtins.y2debug("device name mapping to kernel names: %1", @all_devices)

      nil
    end



    # FATE #302219 - Use and choose persistent device names for disk devices
    # Converts a "/dev/disk/by-" device name to the corresponding kernel
    # device name, if a mapping for this name can be found in the map from
    # yast2-storage. If the given device name is not a "/dev/disk/by-" device
    # name, it is left unchanged. Also, if the information about the device
    # name cannot be found in the target map from yast2-storage, the device
    # name is left unchanged.
    #
    # @param [String] dev string device name
    # @return [String] kernel device name

    def MountByDev2Dev(dev)
      Builtins.y2milestone("MountByDev2Dev: %1", dev)

      return dev if !Builtins.regexpmatch(dev, "^/dev/disk/by-")
      ret = dev

      # check if it is device name by id
      ret = Ops.get(@all_devices, dev, "") if Builtins.haskey(@all_devices, dev)

      Builtins.y2milestone("Device %1 was converted to: %2", dev, ret)
      ret
    end

    # bnc#594482 - grub config not using uuid
    # Function check if proposed_partition still includes
    # flag "create"
    #
    # @param [Hash{String => map}] tm
    # @return true if partition is still not created

    def CheckProposedPartition(tm)
      tm = deep_copy(tm)
      ret = true
      if !Mode.installation
        Builtins.y2debug(
          "Skip CheckProposedPartition() -> it is not running installation"
        )
        return false
      end
      if Builtins.size(tm) == 0 || @proposed_partition == ""
        Builtins.y2debug("proposed_partition is empty: %1", @proposed_partition)
        return false
      end
      dp = Storage.GetDiskPartition(@proposed_partition)
      disk = Ops.get_string(dp, "disk", "")
      partitions = Ops.get_list(tm, [disk, "partitions"], [])
      Builtins.foreach(partitions) do |p|
        if Ops.get_string(p, "device", "") == @proposed_partition
          if Ops.get(p, "create") != true
            @proposed_partition = ""
            Builtins.y2milestone("proposed_partition is already created: %1", p)
            @all_devices_created = 2 if @all_devices_created == 1
            @all_partitions_created = 2 if @all_partitions_created == 1
            ret = false
          else
            Builtins.y2milestone(
              "proposed_partition: %1 is NOT created",
              @proposed_partition
            )
          end
          raise Break
        end
      end
      ret
    end

    # bnc#594482 - grub config not using uuid
    # Check if it is necessary rebuild all_devices
    #
    # @return true -> rebuild all_devices

    def RebuildMapDevices
      ret = false
      ret_CheckProposedPartition = CheckProposedPartition(Storage.GetTargetMap)

      return true if !ret_CheckProposedPartition && @all_devices_created == 2

      ret
    end

    # Init and fullfil internal data for perl-Bootloader
    #
    # @return true if init reset/fullfil data or false and used cached data

    def InitMapDevices
      ret = false
      if @disk_change_time_InitBootloader != Storage.GetTargetChangeTime ||
          RebuildMapDevices()
        Builtins.y2milestone("Init internal data from storage")
        MapDevices()
        @disk_change_time_InitBootloader = Storage.GetTargetChangeTime
        ret = true
      end

      ret
    end

    # bnc#594482 - grub config not using uuid
    # Check if it is necessary rebuild all_partitions and all_disks
    #
    # @return true -> rebuild all_partitions and all_disks

    def RebuilMapAllPartitions
      ret = false
      ret_CheckProposedPartition = CheckProposedPartition(Storage.GetTargetMap)

      return true if !ret_CheckProposedPartition && @all_partitions_created == 2

      ret
    end

    # bnc #468922 - problem with longtime running the parsing a huge number of disks
    # Function initialize all_partitions only if storage change
    # partitioning of disk
    # true if init all_partitions

    def MapAllPartitions
      ret = false
      if @disk_change_time_MapAllPartitions != Storage.GetTargetChangeTime ||
          Ops.less_than(Builtins.size(@all_partitions), 1) ||
          Ops.less_than(Builtins.size(@target_map), 1) ||
          RebuilMapAllPartitions()
        # save last change time from storage for MapAllPartitions()
        @disk_change_time_MapAllPartitions = Storage.GetTargetChangeTime

        @all_partitions = {}
        @target_map = {}
        # get target map
        @target_map = Storage.GetTargetMap
        # map all partitions
        Builtins.foreach(@target_map) do |k, v|
          Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
            # bnc#594482 - grub config not using uuid
            # if there is "not created" partition and flag for "it" is not set
            if Ops.get(p, "create") == true && Mode.installation
              if @proposed_partition == ""
                @proposed_partition = Ops.get_string(p, "device", "")
              end
              @all_partitions_created = 1
            end
            Ops.set(@all_partitions, Ops.get_string(p, "device", ""), p)
          end
        end
        ret = true
      end
      if Mode.installation && @all_partitions_created == 2
        @all_partitions_created = 0
        Builtins.y2milestone("set status for all_partitions to \"created\"")
      end

      ret
    end

    # FATE #302219 - Use and choose persistent device names for disk devices
    # Converts a device name to the corresponding device name it should be
    # mounted by, according to the "mountby" setting for the device from
    # yast2-storage. As a safeguard against problems, if the "mountby" device
    # name does not exist in the information from yast2-storage, it will
    # fallback to the "kernel name" ("/dev/sdXY").
    #
    # @param [String] dev string device name
    # @return [String] device name according to "mountby"
    def Dev2MountByDev(dev)
      tmp_dev = MountByDev2Dev(dev)

      Builtins.y2milestone(
        "Dev2MountByDev: %1 as kernel device name: %2",
        dev,
        tmp_dev
      )
      # add all_partitions to partitions
      Builtins.y2milestone("Init all_partitions was done") if MapAllPartitions()

      partitions = deep_copy(@all_partitions)
      devices = deep_copy(@target_map)

      # (`id,`uuid,`path,`device,`label)
      by_mount = nil

      # bnc#458018 accept different mount-by for partition
      # created by user
      if !Arch.ppc
        by_mount = Storage.GetDefaultMountBy
        if Builtins.haskey(partitions, tmp_dev)
          partition_mount_by = Ops.get_symbol(partitions, [tmp_dev, "mountby"])
          by_mount = partition_mount_by if partition_mount_by != nil
        end
      else
        by_mount = :id
      end

      Builtins.y2milestone("Mount-by: %1", by_mount)
      ret = tmp_dev
      case by_mount
        when :id
          # partitions
          if Ops.get(partitions, [tmp_dev, "udev_id"]) != nil &&
              Ops.get(partitions, [tmp_dev, "udev_id", 0]) != ""
            ret = Builtins.sformat(
              "/dev/disk/by-id/%1",
              Ops.get_string(partitions, [tmp_dev, "udev_id", 0], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to udev id: %2",
              tmp_dev,
              ret
            )
            return ret
          end
          # disks
          if Ops.get(devices, [tmp_dev, "udev_id"]) != nil &&
              Ops.get(devices, [tmp_dev, "udev_id", 0]) != ""
            ret = Builtins.sformat(
              "/dev/disk/by-id/%1",
              Ops.get_string(devices, [tmp_dev, "udev_id", 0], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to udev id: %2",
              tmp_dev,
              ret
            )
            return ret
          end
        when :uuid
          # partitions
          # watch out for fake uuids (shorter than 9 chars)
          if Ops.greater_than(
              Builtins.size(Ops.get_string(partitions, [tmp_dev, "uuid"], "")),
              8
            )
            ret = Builtins.sformat(
              "/dev/disk/by-uuid/%1",
              Ops.get_string(partitions, [tmp_dev, "uuid"], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to uuid: %2",
              tmp_dev,
              ret
            )
            return ret
          end
          # disks
          if Ops.get(devices, [tmp_dev, "uuid"]) != nil &&
              Ops.get(devices, [tmp_dev, "uuid"]) != ""
            ret = Builtins.sformat(
              "/dev/disk/by-uuid/%1",
              Ops.get_string(devices, [tmp_dev, "uuid"], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to uuid: %2",
              tmp_dev,
              ret
            )
            return ret
          end
        when :path
          # partitions
          if Ops.get(partitions, [tmp_dev, "udev_path"]) != nil &&
              Ops.get(partitions, [tmp_dev, "udev_path"]) != ""
            ret = Builtins.sformat(
              "/dev/disk/by-path/%1",
              Ops.get_string(partitions, [tmp_dev, "udev_path"], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to udev path: %2",
              tmp_dev,
              ret
            )
            return ret
          end
          # disks
          if Ops.get(devices, [tmp_dev, "udev_path"]) != nil &&
              Ops.get(devices, [tmp_dev, "udev_path"]) != ""
            ret = Builtins.sformat(
              "/dev/disk/by-path/%1",
              Ops.get_string(devices, [tmp_dev, "udev_path"], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to udev path: %2",
              tmp_dev,
              ret
            )
            return ret
          end
        when :label
          # partitions
          if Ops.get(partitions, [tmp_dev, "label"]) != nil &&
              Ops.get(partitions, [tmp_dev, "label"]) != ""
            ret = Builtins.sformat(
              "/dev/disk/by-label/%1",
              Ops.get_string(partitions, [tmp_dev, "label"], "")
            )
            Builtins.y2milestone(
              "Device name: %1 is converted to label: %2",
              tmp_dev,
              ret
            )
            return ret
          end
          # disks
          Builtins.y2milestone(
            "Disk doesn't support labels - name: %1 is converted to label: %2",
            tmp_dev,
            ret
          )
          return ret
        else
          Builtins.y2warning(
            "Convert %1 to `device or unknown type, result: %2",
            tmp_dev,
            ret
          )
          return ret
      end

      ret
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
      num_of_real_disk = 0
      Builtins.foreach(tm) do |disk, disk_info|
        if Ops.get(disk_info, "type") == :CT_DMMULTIPATH
          devices = Ops.get_list(disk_info, "devices", [])
          if Ops.greater_than(Builtins.size(devices), 0)
            Builtins.foreach(devices) { |d| Ops.set(ret, d, disk) }
          end
        end
        if Ops.get(disk_info, "type") == :CT_DISK
          num_of_real_disk = Ops.add(num_of_real_disk, 1)
        end
        @bois_id_missing = false if Ops.get(disk_info, "bios_id") != nil
      end
      @bois_id_missing = false if num_of_real_disk == 1
      deep_copy(ret)
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
        @multipath_mapping = {}
        @partinfo = []
        @mountpoints = {}

        tm = Storage.GetTargetMap

        @multipath_mapping = mapRealDevicesToMultipath
        @mountpoints = Builtins.mapmap(
          Convert.convert(
            Storage.GetMountPoints,
            :from => "map",
            :to   => "map <string, list>"
          )
        ) do |k, v|
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
          mount_by = Dev2MountByDev(
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


    #** helper functions for ProposeDeviceMap: **
    # Returns true if any device from list devices is in device_mapping
    # marked as hd0.
    def isHd0(devices)
      devices = deep_copy(devices)
      ret = false

      Builtins.foreach(devices) do |value|
        ret = true if Ops.get(@device_mapping, value, "") == "hd0"
      end

      ret
    end

    # Returns first key from mapping associated with value.
    # Example:
    #      map = $[ "a" : "1",
    #               "b" : "2",
    #               "c" : "3",
    #               "d" : "2"];
    #      getDeviceFromMapping("1", map) -> "a"
    #      getDeviceFromMapping("2", map) -> "b"
    def getKey(value, mapping)
      mapping = deep_copy(mapping)
      ret = ""

      Builtins.foreach(mapping) do |key, val|
        if value == val
          ret = key
          next
        end
      end

      ret
    end

    # This function changes order of devices in device_mapping.
    # All devices listed in bad_devices are maped to "hdN" are moved to the end
    # (with changed number N). And second step is putting device with boot partition
    # on top (i.e. device_mapping[dev_with_boot] = "hd0").
    #
    # Example:
    #      device_mapping = $[ "/dev/sda" : "hd0",
    #                          "/dev/sdb" : "hd1",
    #                          "/dev/sdc" : "hd2",
    #                          "/dev/sdd" : "hd3",
    #                          "/dev/sde" : "hd4" ];
    #      bad_devices = [ "/dev/sda", "/dev/sdc" ];
    #
    #      changeOrderInDeviceMapping(bad_devices);
    #      // after call, device_mapping is:
    #      device_mapping -> $[ "/dev/sda" : "hd3",
    #                           "/dev/sdb" : "hd0",
    #                           "/dev/sdc" : "hd4",
    #                           "/dev/sdd" : "hd1",
    #                           "/dev/sde" : "hd2" ];
    def changeOrderInDeviceMapping(bad_devices)
      bad_devices = deep_copy(bad_devices)
      cur_id = 0
      keys = []
      value = ""
      tmp = ""
      tmp2 = ""

      # get keys from device_mapping, it's not possible to use foreach over keys and values
      # of device_mapping directly, because during the loop device_mapping is changing.
      Builtins.foreach(@device_mapping) do |key, value2|
        keys = Builtins.add(keys, key)
      end

      # put bad_devices at bottom
      Builtins.foreach(
        Convert.convert(keys, :from => "list", :to => "list <string>")
      ) do |key|
        value = Ops.get(@device_mapping, key, "")
        # if device is mapped on hdX and this device is _not_ in bad_devices
        if Builtins.substring(value, 0, 2) == "hd" &&
            !Builtins.contains(bad_devices, key)
          # get device name of mapped on "hd"+cur_id
          tmp = getKey(
            Ops.add("hd", Builtins.tostring(cur_id)),
            @device_mapping
          )

          # swap tmp and key devices (swap their mapping)
          Ops.set(@device_mapping, tmp, value)
          Ops.set(
            @device_mapping,
            key,
            Ops.add("hd", Builtins.tostring(cur_id))
          )

          cur_id = Ops.add(cur_id, 1)
        end
      end

      nil
    end

    # Check if MD raid is build on disks not on paritions
    # @param [Array<String>] devices - list of devices from MD raid
    # @param [Hash{String => map}] tm - unfiltered target map
    # @return - true if MD RAID is build on disks (not on partitions)

    def checkMDRaidDevices(devices, tm)
      devices = deep_copy(devices)
      tm = deep_copy(tm)
      ret = true
      Builtins.foreach(devices) do |key|
        if key != "" && ret
          if Ops.get(tm, key) != nil
            ret = true
          else
            ret = false
          end
        end
      end
      ret
    end

    # Function check if disk is in list of devices
    # @param [String] disk
    # @param list<string> list of devices
    # @return true if success

    def isDiskInList(disk, devices)
      devices = deep_copy(devices)
      ret = false
      Builtins.foreach(devices) do |dev|
        if dev == disk
          ret = true
          raise Break
        end
      end
      ret
    end

    # Check if disk is in MDRaid it means completed disk is used in RAID
    # @param [String] disk (/dev/sda)
    # @param [Hash{String => map}] tm - target map
    # @return - true if disk (not only part of disk) is in MDRAID
    def isDiskInMDRaid(disk, tm)
      tm = deep_copy(tm)
      ret = false
      Builtins.foreach(tm) do |dev, d_info|
        if Ops.get(d_info, "type") == :CT_MDPART
          ret = isDiskInList(disk, Ops.get_list(d_info, "devices", []))
        end
        raise Break if ret
      end
      ret
    end



    #** helper functions END **

    # Generate device map proposal, store it in internal variables.
    #
    # FATE #302075:
    #   When user is installing from USB media or any non IDE disk or bios simply
    #   set any non IDE disk as first and user is not installing on this removable
    #   (non IDE) disk, the order of disks proposed by bios must be changed because
    #   of future remove of USB disk.
    #   This function must find right place for bootloader (which is most probably
    #   boot sector of boot partition (where /boot dir is located)) and change the
    #   order of disks in device map.
    #   This method is only heuristic because order of disks after remove of usb
    #   disk can't be determined by any method.
    #
    #   Algorithm for solving problem with usb disk propsed by bios as hd0:
    #      if usbDiskDevice == hd0 && BootDevice != usbDiskDevice:
    #          change order of disks in device_mappings to have BootDevice as hd0
    # FIXME: remove that function from here, as it is grub only
    # NOTE: there is a local copy in routines/grub/misc.ycp now
    def ProposeDeviceMap
      usb_disks = [] # contains those usb removable disks

      @device_mapping = {}
      @multipath_mapping = {}

      targetMap = {}
      if Mode.config
        Builtins.y2milestone("Skipping device map proposing in Config mode")
      else
        targetMap = Storage.GetTargetMap
      end

      # filter out non-disk devices
      targetMap = Builtins.filter(targetMap) do |k, v|
        Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_DMRAID ||
          Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_DISK ||
          Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_DMMULTIPATH ||
          Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_MDPART &&
            checkMDRaidDevices(Ops.get_list(v, "devices", []), targetMap)
      end

      # filter out members of BIOS RAIDs and multipath devices
      targetMap = Builtins.filter(targetMap) do |k, v|
        Ops.get(v, "used_by_type") != :UB_DMRAID &&
          Ops.get(v, "used_by_type") != :UB_DMMULTIPATH &&
          (Ops.get(v, "used_by_type") == :UB_MDPART ?
            !isDiskInMDRaid(k, targetMap) :
            true)
      end

      Builtins.y2milestone("Target map: %1", targetMap)

      # add devices with known bios_id
      # collect BIOS IDs which are used
      ids = {}
      Builtins.foreach(targetMap) do |target_dev, target|
        bios_id = Ops.get_string(target, "bios_id", "")
        if bios_id != ""
          index = case
            when (Arch.i386 || Arch.x86_64) then
              bios_id.to_i - 0x80
            when Arch.board_chrp then
              bios_id.[-1]
            else raise "bios_id is nil"
          end
          grub_dev = Builtins.sformat("hd%1", index)
          # FATE #303548 - doesn't add disk with same bios_id with different name (multipath machine)
          if !Ops.get_boolean(ids, index, false)
            Ops.set(@device_mapping, target_dev, grub_dev)
            Ops.set(ids, index, true)
          end
        end
      end
      # and guess other devices
      # don't use already used BIOS IDs
      Builtins.foreach(targetMap) do |target_dev, target|
        bios_id = Ops.get_string(target, "bios_id", "")
        if bios_id == ""
          index = 0
          while Ops.get_boolean(ids, index, false)
            index = Ops.add(index, 1)
          end
          grub_dev = Builtins.sformat("hd%1", index)
          Ops.set(@device_mapping, target_dev, grub_dev)
          Ops.set(ids, index, true)
        end
      end

      # Fill usb_disks list with usb removable devices.
      #
      # It's not easy to determine how to identify removable usb devices. Now
      # it tests if driver of device is usb-storage. If you find better
      # algorithm how to find removable usb devices, put it here into foreach
      # to apply this algorithm on all devices.
      Builtins.foreach(targetMap) do |target_dev, target|
        driver = Ops.get_string(target, "driver", "")
        if driver == "usb-storage"
          usb_disks = Builtins.add(usb_disks, target_dev)
        end
      end
      Builtins.y2milestone("Found usb discs: %1", usb_disks)

      # change order in device_mapping if usb disk is hd0
      # (FATE #302075)
      if isHd0(usb_disks) &&
          @BootPartitionDevice != getKey("hd0", @device_mapping)
        Builtins.y2milestone("Detected device mapping: %1", @device_mapping)
        Builtins.y2milestone("Changing order in device mapping needed...")
        changeOrderInDeviceMapping(usb_disks)
      end

      @bois_id_missing = false if Builtins.size(@device_mapping) == 1
      if StorageDevices.FloppyPresent
        Ops.set(@device_mapping, StorageDevices.FloppyDevice, "fd0")
      end

      Builtins.y2milestone("Detected device mapping: %1", @device_mapping)

      @multipath_mapping = mapRealDevicesToMultipath

      Builtins.y2milestone("Detected multipath mapping: %1", @multipath_mapping)

      nil
    end

    # Get the order of disks according to BIOS mapping
    # @return a list of all disks in the order BIOS sees them
    def DisksOrder
      if @device_mapping == nil || Builtins.size(@device_mapping) == 0
        ProposeDeviceMap()
      end
      devmap_rev = Builtins.mapmap(@device_mapping) { |k, v| { v => k } }
      devmap_rev = Builtins.filter(devmap_rev) do |k, v|
        Builtins.substring(k, 0, 2) == "hd"
      end
      order = Builtins.maplist(devmap_rev) { |k, v| v }
      deep_copy(order)
    end


    # Function remap device map to device name (/dev/sda)
    # or to label (ufo_disk)
    # @param map<string,string> device map
    # @return [Hash{String => String}] new device map

    def remapDeviceMap(device_map)
      device_map = deep_copy(device_map)
      by_mount = nil
      if Arch.ppc
        by_mount = :id
      else
        by_mount = Storage.GetDefaultMountBy
      end

      #by_mount = `id;
      return deep_copy(device_map) if by_mount == :label

      ret = {}
      # convert device names in device map to the device names by device or label
      ret = Builtins.mapmap(@device_mapping) do |k, v|
        { MountByDev2Dev(k) => v }
      end

      deep_copy(ret)
    end

    # Get the list of installed floppy drives
    # @return a list of floppy devices
    def getFloppyDevices
      if @floppy_devices == nil
        floppies = Convert.convert(
          SCR.Read(path(".probe.floppy")),
          :from => "any",
          :to   => "list <map>"
        )
        floppies = Builtins.filter(floppies) do |f|
          Ops.get_string(f, "model", "Floppy Disk") == "Floppy Disk"
        end
        @floppy_devices = Builtins.maplist(floppies) do |f|
          Ops.get_string(f, "dev_name", "")
        end
        @floppy_devices = Builtins.filter(@floppy_devices) { |f| f != "" }
      end
      deep_copy(@floppy_devices)
    end

    # Returns list of partitions with "mount by" hints. Goes through the list
    # of partitions passed as a parameter and creates a list of partitions with
    # hints according to the current partitioning requested from
    # yast2-storage. To be used in a combobox or menu.
    #
    # @param [Array<String>] parts_to_get list<string> partitions to list
    # @return a list of strings containing a partition name and a hint (if applicable)
    def getHintedPartitionList(parts_to_get)
      parts_to_get = deep_copy(parts_to_get)
      Builtins.y2milestone("getHintedPartitionList: %1", parts_to_get)
      devices = Storage.GetTargetMap

      # make a map: "/dev/hda1" -> info_map_for_this_partition
      partitions = {}
      Builtins.foreach(devices) do |k, v|
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          Ops.set(partitions, Ops.get_string(p, "device", ""), p)
        end
      end
      Builtins.y2milestone("getHintedPartitionList: partitions %1", partitions)

      mountby = :device
      ret = Builtins.maplist(parts_to_get) do |dev|
        mountby = Ops.get_symbol(partitions, [dev, "mountby"])
        if mountby == :uuid
          # watch out for fake uuids (shorter than 9 chars)
          next Builtins.sformat(
            "%1 (mount by UUID: %2)",
            dev,
            Ops.greater_than(
              Builtins.size(Ops.get_string(partitions, [dev, "uuid"], "")),
              8
            ) ?
              Ops.get_string(partitions, [dev, "uuid"], "") :
              "<UUID to be created later during format>"
          )
        elsif mountby == :label
          next Builtins.sformat(
            "%1 (mount by LABEL: %2)",
            dev,
            Ops.get_string(partitions, [dev, "label"], "")
          )
        elsif mountby == :id
          next Builtins.sformat(
            "%1 (mount by ID: %2)",
            dev,
            Ops.get_string(partitions, [dev, "udev_id", 0], "")
          )
        elsif mountby == :path
          next Builtins.sformat(
            "%1 (mount by PATH: %2)",
            dev,
            Ops.get_string(partitions, [dev, "udev_path"], "")
          )
        elsif mountby == nil || mountby == :device
          next dev
        end
      end

      Builtins.y2milestone("getHintedPartitionList: ret %1", ret)
      deep_copy(ret)
    end

    # Returns list of partitions. Requests current partitioning from
    # yast2-storage and creates list of partition for combobox, menu or other
    # purpose.
    # @param [Symbol] type symbol
    #   `boot - for bootloader installation
    #   `root - for kernel root
    #   `boot_other - for bootable partitions of other systems
    #   `all - all partitions
    #   `parts_old - all partitions, except those what will be created
    #      during isntallation
    #   `deleted - all partitions deleted in current proposal
    #   `kept - all partitions that won't be deleted, new created or formatted
    #   `destroyed - all partition which are new, deleted or formatted
    # @return a list of strings
    def getPartitionList(type, bl)
      Builtins.y2milestone("getPartitionList: %1", type)
      devices = Storage.GetTargetMap
      partitions = []
      Builtins.foreach(devices) do |k, v|
        if type == :boot && bl == "grub"
          # check if device is in device map
          if Builtins.haskey(@device_mapping, k) ||
              Builtins.haskey(@device_mapping, Dev2MountByDev(k))
            partitions = Convert.convert(
              Builtins.merge(partitions, Ops.get_list(v, "partitions", [])),
              :from => "list",
              :to   => "list <map>"
            )
          end
        else
          partitions = Convert.convert(
            Builtins.merge(partitions, Ops.get_list(v, "partitions", [])),
            :from => "list",
            :to   => "list <map>"
          )
        end
      end
      floppies = getFloppyDevices

      devices = Builtins.filter(devices) do |k, v|
        Ops.get_symbol(v, "type", :CT_UNKNOWN) != :CT_LVM
      end

      devices = Builtins.filter(devices) do |k, v|
        if Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_DISK ||
            Ops.get_symbol(v, "type", :CT_UNKNOWN) == :CT_DMRAID
          next true
        else
          next false
        end
      end if type == :boot ||
        type == :boot_other
      all_disks = Builtins.maplist(devices) { |k, v| k }



      if type == :deleted
        return Builtins.maplist(Builtins.filter(partitions) do |p|
          Ops.get_boolean(p, "delete", false)
        end) { |x| Ops.get_string(x, "device", "") }
      elsif type == :destroyed
        return Builtins.maplist(Builtins.filter(partitions) do |p|
          Ops.get_boolean(p, "delete", false) ||
            Ops.get_boolean(p, "format", false) ||
            Ops.get_boolean(p, "create", false)
        end) { |x| Ops.get_string(x, "device", "") }
      end
      partitions = Builtins.filter(partitions) do |p|
        !Ops.get_boolean(p, "delete", false)
      end
      # filter out disk which are not in device map
      all_disks = Builtins.filter(all_disks) do |k|
        if Builtins.haskey(@device_mapping, k) ||
            Builtins.haskey(@device_mapping, Dev2MountByDev(k))
          next true
        else
          next false
        end
      end if bl == "grub" &&
        type == :boot
      ret = deep_copy(all_disks)
      if type == :boot_other || type == :root || type == :parts_old ||
          type == :kept
        ret = []
      end

      if type == :boot
        partitions = Builtins.filter(partitions) do |p|
          Ops.get_symbol(p, "type", :primary) == :primary ||
            Ops.get_symbol(p, "type", :primary) == :extended ||
            Ops.get_symbol(p, "type", :primary) == :logical ||
            Ops.get_symbol(p, "type", :primary) == :sw_raid
        end
        # FIXME this checking is performed on 3 places, one function should
        # be developed for it
        partitions = Builtins.filter(partitions) do |p|
          fs = Ops.get_symbol(p, "used_fs", Ops.get(p, "detected_fs"))
          next false if fs == :xfs
          true
        end
      elsif type == :root
        partitions = Builtins.filter(partitions) do |p|
          Ops.get_symbol(p, "type", :primary) != :extended
        end
      elsif type == :prep
	partitions = Builtins.filter(partitions) do |p|
	  Ops.get_integer(p, "fsid", 65) == 65
	end
      elsif type == :parts_old
        partitions = Builtins.filter(partitions) do |p|
          !Ops.get_boolean(p, "create", false)
        end
      elsif type == :kept
        partitions = Builtins.filter(partitions) do |p|
          !(Ops.get_boolean(p, "create", false) ||
            Ops.get_boolean(p, "format", false))
        end
      end
      if type != :all && type != :parts_old && type != :kept
        partitions = Builtins.filter(partitions) do |p|
          Ops.get_string(p, "fstype", "") != "Linux swap"
        end
      end
      partitions = Builtins.filter(partitions) do |p|
        Ops.get_string(p, "fstype", "") == "Linux native" ||
          Ops.get_string(p, "fstype", "") == "Extended" ||
          Ops.get_string(p, "fstype", "") == "Linux RAID" ||
          Builtins.tolower(Ops.get_string(p, "fstype", "")) == "md raid" ||
          Ops.get_string(p, "fstype", "") == "DM RAID"
      end if type == :boot

      partition_names = Builtins.maplist(partitions) do |p|
        Ops.get_string(p, "device", "")
      end
      partition_names = Builtins.filter(partition_names) { |p| p != "" }
      partition_names = Convert.convert(
        Builtins.merge(partition_names, floppies),
        :from => "list",
        :to   => "list <string>"
      )
      ret = Convert.convert(
        Builtins.union(ret, partition_names),
        :from => "list",
        :to   => "list <string>"
      )
      ret = Builtins.toset(ret)
      deep_copy(ret)
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
      if @PRePPartitionDevice != "" && @PRePPartitionDevice != nil
        boot_devices = Builtins.add(boot_devices, @PRePPartitionDevice)
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

    publish :variable => :disk_change_time_InitBootloader, :type => "integer"
    publish :variable => :disk_change_time_MapAllPartitions, :type => "integer"
    publish :variable => :disk_change_time_checkCallingDiskInfo, :type => "integer"
    publish :variable => :all_partitions, :type => "map <string, map>"
    publish :variable => :all_devices, :type => "map <string, string>"
    publish :variable => :multipath_mapping, :type => "map <string, string>"
    publish :variable => :mountpoints, :type => "map <string, any>"
    publish :variable => :partinfo, :type => "list <list>"
    publish :variable => :md_info, :type => "map <string, list <string>>"
    publish :variable => :bois_id_missing, :type => "boolean"
    publish :variable => :device_mapping, :type => "map <string, string>"
    publish :variable => :BootPartitionDevice, :type => "string"
    publish :variable => :RootPartitionDevice, :type => "string"
    publish :variable => :ExtendedPartitionDevice, :type => "string"
    publish :variable => :PRePPartitionDevice, :type => "string"
    publish :variable => :floppy_devices, :type => "list <string>"
    publish :variable => :md_physical_disks, :type => "list <string>"
    publish :function => :MountByDev2Dev, :type => "string (string)"
    publish :function => :InitMapDevices, :type => "boolean ()"
    publish :function => :Dev2MountByDev, :type => "string (string)"
    publish :function => :InitDiskInfo, :type => "void ()"
    publish :function => :ProposeDeviceMap, :type => "void ()"
    publish :function => :DisksOrder, :type => "list <string> ()"
    publish :function => :remapDeviceMap, :type => "map <string, string> (map <string, string>)"
    publish :function => :getFloppyDevices, :type => "list <string> ()"
    publish :function => :getHintedPartitionList, :type => "list <string> (list <string>)"
    publish :function => :getPartitionList, :type => "list <string> (symbol, string)"
    publish :function => :checkMDSettings, :type => "boolean ()"
    publish :function => :addMDSettingsToGlobals, :type => "string ()"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
