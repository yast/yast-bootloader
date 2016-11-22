require "yast"

Yast.import "BootStorage"
Yast.import "Storage"
Yast.import "Partitions"

module Bootloader
  # Purpose of this class is provide mapping between intentioned stage1 location
  # and real one as many virtual devices cannot be used for stage1 like md
  # devices or lvm
  #
  # @example
  #   # system with lvm, /boot lives on /dev/system/root. /dev/system is
  #   # created from /dev/sda1 and /dev/sdb1
  #   dev = Stage1Device.new("/dev/system/boot")
  #   puts dev.real_devices # => ["/dev/sda1", "/dev/sdb1"]
  class Stage1Device
    include Yast::Logger

    # @param [String] device intended location of stage1. Device here
    #   means any name  under /dev like "/dev/sda", "/dev/system/root" or
    #   "/dev/md-15". Such device have to be in kernel name, so no udev links.
    def initialize(device)
      @intended_device = device
    end

    # @return [Array<String>] list of devices where stage1 need to be installed
    # to fit the best intended device. Devices used kernel device names, so no
    # udev names
    def real_devices
      return @real_devices if @real_devices

      @real_devices = underlaying_devices_for(@intended_device)

      log.info "Stage1 real devices for #{@intended_device} is #{@real_devices}"

      @real_devices
    end

  private

    # underlaying_devices without any caching
    # @see #underlaying_devices
    def underlaying_devices_for(dev)
      res = underlaying_devices_one_level(dev)

      # some underlaying devices added, so run recursive to ensure that it is really bottom one
      res = res.each_with_object([]) { |d, f| f.concat(underlaying_devices_for(d)) }

      # TODO: check if res empty is caused by filtering out lvm on partitionless disk
      res = [dev] if res.empty?

      res.uniq
    end

    # get one level of underlaying devices, so no recursion deeper
    def underlaying_devices_one_level(dev)
      tm = Yast::Storage.GetTargetMap
      disk_data = Yast::Storage.GetDiskPartition(dev)
      if disk?(disk_data)
        disk = Yast::Storage.GetDisk(tm, dev)
        # md disk is just virtual device, so select underlaying device /boot partition
        case disk["type"]
        when :CT_MD then return underlaying_disk_with_boot_partition
        when :CT_LVM
          res = lvm_underlaying_devices(disk)
          return res.map { |r| Yast::Storage.GetDiskPartition(r)["disk"] }
        when :CT_DMRAID
          return disk["devices"]
        end
      # given device is partition
      else
        part = Yast::Storage.GetPartition(tm, dev)
        if part["type"] == :lvm
          lvm_group = Yast::Storage.GetDisk(tm, disk_data["disk"])
          return lvm_underlaying_devices(lvm_group)
        elsif part["type"] == :sw_raid
          return devices_on(part)
        elsif part["fstype"] == Yast::Partitions.dmraid_name
          mapper = Yast::Storage.GetDisk(tm, disk_data["disk"])
          return mapper["devices"]
        end
      end

      []
    end

    # For pure virtual disk devices it is selected /boot partition and its
    # underlaying devices then for it select on which disks it lives. So result
    # is disk which contain partition holding /boot.
    def underlaying_disk_with_boot_partition
      underlaying_devices_for(Yast::BootStorage.BootPartitionDevice).map do |part|
        disk_dev = Yast::Storage.GetDiskPartition(part)
        disk_dev["disk"]
      end
    end

    # returns underlaying devices that creating lvm group
    def lvm_underlaying_devices(lvm_group)
      tm = Yast::Storage.GetTargetMap
      res = devices_on(lvm_group)
      # skip lvm on partiotionless disks as it cannot be used, see bnc#980529
      res.reject { |d| tm[d] }
    end

    # returns if given result of GetDiskPartition indicate that it is disk
    def disk?(disk_data)
      disk_data["nr"].to_s.empty?
    end

    # returns devices which constructed passed device.
    # @param [Hash] dev is part of target map with given device
    def devices_on(dev)
      (dev["devices"] || []) + (dev["devices_add"] || [])
    end
  end
end
