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
          disks << disk
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
          if p_devices.size == 2 # TODO: why only 2? it do not make sense
            ret = checkDifferentDisks(p_devices)
          else
            log.info "Device: #{device} doesn't contain 2 partitions: #{p_devices}"
          end
        else
          log.info "Device: #{device} is not on raid1: #{p["raid_type"]}"
        end
      end

      log.info "device: #{device} is based on md_physical_disks: #{@md_physical_disks}"\
        "is #{ret ? "valid" : "invalid"} for enable redundancy"

      ret
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Function check partitions and set redundancy available if
    # partitioning of disk allows it.
    # It means if md array is based on 2 partitions with same number but 2 different disks
    # E.g. /dev/md0 is from /dev/sda1 and /dev/sb1 and /dev/md0 is "/"
    # There is possible only boot from MBR (GRUB not generic boot code)
    #
    # @return [Array] Array of devices that can be used to redundancy boot

    def devices_for_redundant_boot
      tm = Storage.GetTargetMap

      if !tm["/dev/md"]
        log.info "Doesn't include md raid"
        return []
      end

      boot_devices = [@BootPartitionDevice]
      if @BootPartitionDevice != @RootPartitionDevice
        boot_devices << @RootPartitionDevice
      end
      boot_devices << @ExtendedPartitionDevice
      boot_devices.delete_if { |d| d.nil? || d.empty? }

      log.info "Devices for analyse of redundacy md array: #{boot_devices}"

      boot_devices.each do |dev|
        ret = checkMDDevices(tm, dev)
        # only log if device is not suitable, otherwise md redundancy is not
        # allowed even if there is some suitable device (bnc#917025)
        log.info "Skip enable redundancy for device #{dev}" unless ret
      end

      @md_physical_disks
    end

    # returns device where dev physically lives, so where can be bootloader installed
    # it is main entry point when real stage 1 device is needed to get
    def underlaying_devices(dev)
      return @underlaying_devices_cache[dev] if @underlaying_devices_cache[dev]

      res = []

      tm = Yast::Storage.GetTargetMap
      disk_data = Yast::Storage.GetDiskPartition(dev)
      if disk_data["nr"].to_s.empty? # disk
        disk = Yast::Storage.GetDisk(tm, dev)
        if disk["type"] == :CT_MD
          # md disk is just virtual device, so lets use boot partition location
          # in raid and get its disks
          res = underlaying_devices(BootPartitionDevice()).map do |part|
            disk_dev = Yast::Storage.GetDiskPartition(part)
            disk_dev["disk"]
          end
        elsif disk["type"] == :CT_LVM
          # not happy with this usage of || but target map do not need to have it defined
          res = (disk["devices"] || []) + (disk["devices_add"] || [])
          res.map! { |r| Yast::Storage.GetDiskPartition(r)["disk"] }
        end
      else
        part = Yast::Storage.GetPartition(tm, dev)
        if part["type"] == :lvm
          lvm_dev = Yast::Storage.GetDisk(tm, disk_data["disk"])
          res = (lvm_dev["devices"] || []) + (lvm_dev["devices_add"] || [])
        elsif part["type"] == :sw_raid
          res = (part["devices"] || []) + (part["devices_add"] || [])
        end
      end

      # some underlaying devices added, so run recursive to ensure that it is really bottom one
      res = res.each_with_object([]) { |d, f| f.concat(underlaying_devices(d)) }

      res = [dev] if res.empty?

      res.uniq!

      @underlaying_devices_cache[dev] = res

      log.info "underlaying device for #{dev} is #{res.inspect}"

      res
    end

    # Converts the md device to the list of devices building it
    # @param [String] md_device string md device
    # @return a map of devices from device name to BIOS ID or empty hash if
    #   not detected) building the md device
    def Md2Partitions(md_device)
      ret = {}
      tm = Storage.GetTargetMap
      tm.each_pair do |_disk, descr|
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
      # FIXME: handle somehow if disk are in logical raid
      partitions = Md2Partitions(partition).keys
      partitions = [partition] if partitions.empty?
      res = partitions.map do |part|
        Storage.GetDiskPartition(part)["disk"]
      end
      res.uniq!
      # handle LVM disks
      tm = Storage.GetTargetMap
      res = res.each_with_object([]) do |disk, ret|
        disk_meta = tm[disk]
        next unless disk_meta

        if disk_meta["lvm2"]
          devices = (disk_meta["devices"] || []) + (disk_meta["devices_add"] || [])
          disks = devices.map { |d| real_disks_for_partition(d) }
          ret.concat(disks.flatten)
        else
          ret << disk
        end
      end

      res.uniq
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

    def encrypted_boot?
      dev = BootPartitionDevice()
      tm = Yast::Storage.GetTargetMap || {}
      tm.each_value do |v|
        partitions = v["partitions"] || []
        partition = partitions.find { |p| p["device"] == dev || p["crypt_device"] == dev }

        next unless partition

        return partition["crypt_device"] && !partition["crypt_device"].empty?
      end
    end

    publish :variable => :BootPartitionDevice, :type => "string"
    publish :variable => :RootPartitionDevice, :type => "string"
    publish :variable => :ExtendedPartitionDevice, :type => "string"
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
  end

  BootStorage = BootStorageClass.new
  BootStorage.main
end
