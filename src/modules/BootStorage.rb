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
require "bootloader/device_mapping"

module Yast
  class BootStorageClass < Module
    include Yast::Logger
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
      @device_mapping = {}

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
      Builtins.foreach(tm) do |disk, disk_info|
        if Ops.get(disk_info, "type") == :CT_DMMULTIPATH
          devices = Ops.get_list(disk_info, "devices", [])
          if Ops.greater_than(Builtins.size(devices), 0)
            Builtins.foreach(devices) { |d| Ops.set(ret, d, disk) }
          end
        end
      end
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
          mount_by = ::Bootloader::DeviceMapping.to_mountby_device(
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
      devices.any? { |dev| @device_mapping[dev] == "hd0" }
    end

    # This function changes order of devices in device_mapping.
    # All devices listed in bad_devices are maped to "hdN" are moved to the end
    # (with changed number N). Priority device are always placed at first place    #
    # Example:
    #      device_mapping = $[ "/dev/sda" : "hd0",
    #                          "/dev/sdb" : "hd1",
    #                          "/dev/sdc" : "hd2",
    #                          "/dev/sdd" : "hd3",
    #                          "/dev/sde" : "hd4" ];
    #      bad_devices = [ "/dev/sda", "/dev/sdc" ];
    #
    #      changeOrderInDeviceMapping(device_mapping, bad_devices: bad_devices);
    #      // returns:
    #      device_mapping -> $[ "/dev/sda" : "hd3",
    #                           "/dev/sdb" : "hd0",
    #                           "/dev/sdc" : "hd4",
    #                           "/dev/sdd" : "hd1",
    #                           "/dev/sde" : "hd2" ];
    def changeOrderInDeviceMapping(device_mapping, bad_devices: [], priority_device: nil)
      log.info("Calling change of device map with #{device_mapping}, " +
        "bad_devices: #{bad_devices}, priority_device: #{priority_device}")
      device_mapping = device_mapping.dup
      first_available_id = 0
      keys = device_mapping.keys
      # sort keys by its order in device mapping
      keys.sort_by! {|k| device_mapping[k][/\d+$/] }

      if priority_device
        # change order of priority device if it is already in device map, otherwise ignore them
        if device_mapping[priority_device]
          first_available_id = 1
          old_first_device = device_mapping.key("hd0")
          old_device_id = device_mapping[priority_device]
          device_mapping[old_first_device] = old_device_id
          device_mapping[priority_device] = "hd0"
        else
          log.warn("Unknown priority device '#{priority_device}'. Skipping")
        end
      end

      # put bad_devices at bottom
      keys.each do |key|
        value = device_mapping[key]
        if !value # FIXME this should not happen, but openQA catch it, so be on safe side
          log.error("empty value in device map")
          next
        end
        # if device is mapped on hdX and this device is _not_ in bad_devices
        if value.start_with?("hd") &&
            !bad_devices.include?(key) &&
            key != priority_device
          # get device name of mapped on "hd"+cur_id
          tmp = device_mapping.key("hd#{first_available_id}")

          # swap tmp and key devices (swap their mapping)
          device_mapping[tmp] = value
          device_mapping[key] = "hd#{first_available_id}"

          first_available_id += 1
        end
      end

      device_mapping
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

    # Check if disk is in MDRaid it means completed disk is used in RAID
    # @param [String] disk (/dev/sda)
    # @param [Hash{String => map}] tm - target map
    # @return - true if disk (not only part of disk) is in MDRAID
    def isDiskInMDRaid(disk, tm)
      tm.values.any? do |disk_info|
        disk_info["type"] == :CT_MDPART &&
          (disk_info["devices"] || []).include?(disk)
      end
    end

    def propose_s390_device_map
      # s390 have some special requirements for device map. Keep it short and simple (bnc#884798)
      # TODO device map is not needed at all for s390, so if we get rid of perl-Bootloader translations
      # we can keep it empty
        boot_part = Storage.GetEntryForMountpoint("/boot/zipl")
        boot_part = Storage.GetEntryForMountpoint("/boot") if boot_part.empty?
        boot_part = Storage.GetEntryForMountpoint("/") if boot_part.empty?

        raise "Cannot find boot partition" if boot_part.empty?

        disk = Storage.GetDiskPartition(boot_part["device"])["disk"]

        @device_mapping = { "hd0" => disk }

        Builtins.y2milestone("Detected device mapping: %1", @device_mapping)

        nil
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
    #          change order of disks in device_mapping to have BootDevice as hd0
    # FIXME: remove that function from here, as it is grub only
    def ProposeDeviceMap
      @device_mapping = {}
      @multipath_mapping = {}

      if Mode.config
        Builtins.y2milestone("Skipping device map proposing in Config mode")
        return
      end

      if Arch.s390
        return propose_s390_device_map
      end

      usb_disks = [] # contains usb removable disks as it can affect BIOS order of disks

      targetMap = Storage.GetTargetMap

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
          index = case Arch.architecture
          when /ppc/
            # on ppc it looks like "vdevice/v-scsi@71000002/@0"
            bios_id[/\d+\z/].to_i
          when "i386", "x86_64"
            Builtins.tointeger(bios_id) - 0x80
          else
            raise "no support for bios id '#{bios_id}' on #{Arch.architecture}"
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
          @BootPartitionDevice != @device_mapping.key("hd0")
        Builtins.y2milestone("Detected device mapping: %1", @device_mapping)
        Builtins.y2milestone("Changing order in device mapping needed...")
        @device_mapping = changeOrderInDeviceMapping(@device_mapping, bad_devices: usb_disks)
      end

      # For us priority disk is device where /boot or / lives as we control this disk and
      # want to modify its MBR. So we get disk of such partition and change order to add it
      # to top of device map. For details see bnc#887808,bnc#880439
      priority_disks = real_disks_for_partition(@BootPartitionDevice)
      # if none of priority disk is hd0, then choose one and assign it
      if !isHd0(priority_disks)
        @device_mapping = changeOrderInDeviceMapping(@device_mapping,
            priority_device: priority_disks.first)
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
      return [] unless @device_mapping

      disks = @device_mapping.select { |k,v| v.start_with?("hd") }.keys

      disks.sort_by { |d| @device_mapping[d][2..-1].to_i }
    end


    # Function remap device map to device name (/dev/sda)
    # or to label (ufo_disk)
    # @param map<string,string> device map
    # @return [Hash{String => String}] new device map

    def remapDeviceMap(device_map)
      device_map = deep_copy(device_map)
      if Arch.ppc
        by_mount = :id
      else
        by_mount = Storage.GetDefaultMountBy
      end

      #by_mount = `id;
      return device_map if by_mount == :label

      # convert device names in device map to the device names by device or label
      Builtins.mapmap(@device_mapping) do |k, v|
        { ::Bootloader::DeviceMapping.to_kernel_device(k) => v }
      end
    end

    # Returns list of partitions. Requests current partitioning from
    # yast2-storage and creates list of partition usable for boot partition
    def possible_locations_for_stage1
      devices = Storage.GetTargetMap

      all_disks = devices.keys
      # Devices which is not in device map cannot be used to boot
      all_disks.select! do |k|
        @device_mapping.include?(k) ||
          @device_mapping.include?(::Bootloader::DeviceMapping.to_mountby_device(k))
      end

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
    publish :variable => :device_mapping, :type => "map <string, string>"
    publish :variable => :BootPartitionDevice, :type => "string"
    publish :variable => :RootPartitionDevice, :type => "string"
    publish :variable => :ExtendedPartitionDevice, :type => "string"
    publish :function => :InitDiskInfo, :type => "void ()"
    publish :function => :ProposeDeviceMap, :type => "void ()"
    publish :function => :DisksOrder, :type => "list <string> ()"
    publish :function => :remapDeviceMap, :type => "map <string, string> (map <string, string>)"
    publish :function => :getPartitionList, :type => "list <string> (symbol, string)"
    publish :function => :addMDSettingsToGlobals, :type => "string ()"
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
