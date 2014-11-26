require "yast"

require "bootloader/udev_mapping"

module Bootloader
  # Class representing grub device map structure
  class DeviceMap
    include Yast::Logger

    def initialize(mapping = {})
      # lazy load to avoid circular dependencies
      Yast.import "Arch"
      Yast.import "BootStorage"
      Yast.import "Mode"
      Yast.import "Storage"
      @mapping = mapping
    end

    def to_hash
      @mapping.dup
    end

    def to_s
      "Device Map: #{@mapping.inspect}"
    end

    def empty?
      @mapping.empty?
    end

    def contain_disk?(disk)
      @mapping.include?(disk) ||
        @mapping.include?(::Bootloader::UdevMapping.to_mountby_device(disk))
    end

    def disks_order
      disks = @mapping.select { |_k,v| v.start_with?("hd") }.keys

      disks.sort_by { |d| @mapping[d][2..-1].to_i }
    end

    BIOS_LIMIT = 8
    # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
    # The function reduces records (devices) in device.map
    # Grub doesn't support more than 8 devices in device.map
    # @return [Boolean] true if device map was reduced
    def reduce_to_bios_limit
      if @mapping.size <= BIOS_LIMIT
        log.info "device map not need to be reduced"
        return false
      end

      log.info "device map before reduction #{@mapping}"
      @mapping.select! do |_k,v|
        v[2..-1].to_i < BIOS_LIMIT
      end

      log.info "device map after reduction #{@mapping}"

      true
    end

    # Function remap device map to device name (/dev/sda)
    # or to label (ufo_disk)
    # @return [Hash{String => String}] new device map
    def remapped_hash
      if !Yast::Arch.ppc
        return to_hash if Yast::Storage.GetDefaultMountBy == :label
      end

      # convert device names in device map to the device names by device or label
      remapped = @mapping.map do |k, v|
        [UdevMapping.to_kernel_device(k), v]
      end

      Hash[remapped]
    end

    def propose
      @mapping = {}

      if Yast::Mode.config
        log.info("Skipping device map proposing in Config mode")
        return
      end

      if Yast::Arch.s390
        return propose_s390_device_map
      end

      fill_mapping

      order_boot_device
    end

  private

    def order_boot_device
      # For us priority disk is device where /boot or / lives as we control this disk and
      # want to modify its MBR. So we get disk of such partition and change order to add it
      # to top of device map. For details see bnc#887808,bnc#880439
      priority_disks = Yast::BootStorage.real_disks_for_partition(
        Yast::BootStorage.BootPartitionDevice
      )
      # if none of priority disk is hd0, then choose one and assign it
      return if any_first_device?(priority_disks)

      @mapping = change_order(
        @mapping,
        priority_device: priority_disks.first
      )
    end

    def fill_mapping
      target_map = filtered_target_map
      log.info("Filtered target map: #{target_map}")

      # add devices with known bios_id
      # collect BIOS IDs which are used
      ids = {}
      target_map.each do |target_dev, target|
        bios_id = target["bios_id"] || ""
        next if bios_id.empty?

        index = case Yast::Arch.architecture
        when /ppc/
          # on ppc it looks like "vdevice/v-scsi@71000002/@0"
          bios_id[/\d+\z/].to_i
        when "i386", "x86_64"
          # it looks like 0x81. It is boot drive unit see http://en.wikipedia.org/wiki/Master_boot_record
          bios_id[2..-1].to_i(16) - 0x80
        else
          raise "no support for bios id '#{bios_id}' on #{Yast::Arch.architecture}"
        end
        # FATE #303548 - doesn't add disk with same bios_id with different name (multipath machine)
        if !ids[index]
          @mapping[target_dev] = "hd#{index}"
          ids[index] = true
        end
      end
      # and guess other devices
      # don't use already used BIOS IDs
      target_map.each do |target_dev, target|
        next unless target.fetch("bios_id", "").empty?

        index = 0 # find free index
        while ids[index]
          index += 1
        end
        @mapping[target_dev] = "hd#{index}"
        ids[index] = true
      end
    end

    def filtered_target_map
      target_map = Yast::Storage.GetTargetMap.dup

      # select only disk devices
      target_map.select! do |_k, v|
        [:CT_DMRAID, :CT_DISK, :CT_DMMULTIPATH].include?(v["type"]) ||
          ( v["type"] == :CT_MDPART &&
            checkMDRaidDevices(v["devices"] || [], target_map))
      end

      # filter out members of BIOS RAIDs and multipath devices
      target_map.delete_if do |k, v|
        [:UB_DMRAID, :UB_DMMULTIPATH].include?(v["used_by_type"]) ||
          (v["used_by_type"] == :UB_MDPART && isDiskInMDRaid(k, target_map))
      end

      target_map
    end

    def propose_s390_device_map
      # s390 have some special requirements for device map. Keep it short and simple (bnc#884798)
      # TODO: device map is not needed at all for s390, so if we get rid of perl-Bootloader translations
      # we can keep it empty
      boot_part = Yast::Storage.GetEntryForMountpoint("/boot/zipl")
      boot_part = Yast::Storage.GetEntryForMountpoint("/boot") if boot_part.empty?
      boot_part = Yast::Storage.GetEntryForMountpoint("/") if boot_part.empty?

      raise "Cannot find boot partition" if boot_part.empty?

      disk = Yast::Storage.GetDiskPartition(boot_part["device"])["disk"]

      @mapping = { disk => "hd0" }

      log.info "Detected device mapping: #{@mapping}"
    end

    # Returns true if any device from list devices is in device_mapping
    # marked as hd0.
    def any_first_device?(devices)
      devices.any? { |dev| @mapping[dev] == "hd0" }
    end

    # This function changes order of devices in device_mapping.
    # Priority device are always placed at first place    #
    def change_order(device_mapping, priority_device: nil)
      log.info "Change order with #{device_mapping} and priority_device: #{priority_device}"
      return device_mapping unless priority_device

      device_mapping = device_mapping.dup

      # change order of priority device if it is already in device map, otherwise ignore them
      if device_mapping[priority_device]
        old_first_device = device_mapping.key("hd0")
        old_device_id = device_mapping[priority_device]
        device_mapping[old_first_device] = old_device_id
        device_mapping[priority_device] = "hd0"
      else
        log.warn("Unknown priority device '#{priority_device}'. Skipping")
      end

      device_mapping
    end

    # Check if MD raid is build on disks not on paritions
    # @param [Array<String>] devices - list of devices from MD raid
    # @param [Hash{String => map}] tm - unfiltered target map
    # @return - true if MD RAID is build on disks (not on partitions)
    def checkMDRaidDevices(devices, tm)
      ret = true
      devices.each do |key|
        break unless ret
        next if key == ""

        ret = tm[key].nil?
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
  end
end
