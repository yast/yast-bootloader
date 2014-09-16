require "yast"
require "singleton"

Yast.import "Storage"
Yast.import "Mode"
Yast.import "Arch"

module Bootloader
  # Class manages mapping between udev names of disks and partitions.
  class DeviceMapping
    include Singleton
    include Yast::Logger

    # make more comfortable to work with singleton
    class << self
      extend Forwardable
      def_delegators :instance,
        :to_hash,
        :recreate_mapping,
        :to_kernel_device,
        :to_mountby_device
    end

    # TODO remove when remove pbl support
    def to_hash
      ensure_mapping_exists
      @all_devices
    end

    # Converts full udev name to kernel device ( disk or partition )
    # @param dev [String] device udev or kernel one like /dev/disks/by-id/blabla
    # @raise when device have udev format but do not exists
    def to_kernel_device(dev)
      return dev if dev !~ /^\/dev\/disk\/by-/

      ensure_mapping_exists

      @all_devices[dev] or raise "Unknown udev device #{dev}"
    end

    # Converts udev or kernel device (disk or partition) to udev name according to mountby
    # option or kernel device if such udev device do not exists
    # @param dev [String] device udev or kernel one like /dev/disks/by-id/blabla
    # @raise when device have udev format but do not exists
    def to_mountby_device(dev)
      kernel_dev = to_kernel_device(dev)

      log.info "#{dev} looked as kernel device name: #{kernel_dev}"
      # we do not know if it is partition or disk, but target map help us
      target_map = Yast::Storage.GetTargetMap
      data = target_map[kernel_dev]
      if !data #so partition
        disk = target_map[Yast::Storage.GetDiskPartition(kernel_dev)["disk"]]
        data = disk["partitions"].find { |p| p["device"] == kernel_dev }
      end

      raise "Unknown device #{kernel_dev}" unless data

      mount_by = data["mountby"]
      mount_by ||= Yast::Arch.ppc ? :id : Yast::Storage.GetDefaultMountBy

      log.info "mount by: #{mount_by}"

      key = MOUNT_BY_MAPPING_TO_UDEV[mount_by]
      raise "Internal error unknown mountby #{mount_by}" unless key
      ret = map_device_to_udev_devices(data[key], key, kernel_dev)
      if ret.empty?
        log.warn "Cannot find udev link to satisfy mount by for #{kernel_dev}"
        return kernel_dev
      end

      return ret.first.first
    end

    # FIXME Temporary method, will be removed as class itself recognize cache invalidation
    def recreate_mapping
      map_devices
    end
  private

    def ensure_mapping_exists
      map_devices unless cache_valid?
    end

    MOUNT_BY_MAPPING_TO_UDEV = {
      :uuid  => "uuid",
      :id    => "udev_id",
      :path  => "udev_path",
      :label => "label"
    }

    UDEV_MAPPING = {
      "uuid"      => "/dev/disk/by-uuid/",
      "udev_id"   => "/dev/disk/by-id/",
      "udev_path" => "/dev/disk/by-path/",
      "label"     => "/dev/disk/by-label/"
    }

    # Maps udev names to kernel names with given mapping from data to device
    # @private internall use only
    # @note only temporary method
    def map_disks(data, device)
      keys = UDEV_MAPPING.keys - ["label"] #disks do not have labels
      fill_all_devices(keys, data, device)
    end

    def map_partitions(data, device)
      keys = UDEV_MAPPING.keys
      fill_all_devices(keys, data, device)
    end

    def fill_all_devices(keys, data, device)
      keys.each do |key|
        names = data[key]
        @all_devices.merge! Hash[map_device_to_udev_devices(names, key, device)]
      end
    end


    def map_device_to_udev_devices(names, key, device)
      return [] if [nil, "", []].include?(names)
      prefix = UDEV_MAPPING[key]
      names = [names] if names.is_a?(::String)
      ret = names.reduce([]) do |res, name|
        # watch out for fake uuids (shorter than 9 chars)
        next res if name.size < 9 && key == "uuid"
        res << [prefix + name, device]
      end
    end

    # FATE #302219 - Use and choose persistent device names for disk devices
    # Function prepare maps with mapping disks and partitions by uuid, id, path
    # and label.
    #
    def map_devices
      @all_devices = {}
      Yast::Storage.GetTargetMap.each_pair do |device, value|
        map_disks(value, device)

        next unless value["partitions"]

        value["partitions"].each do |partition|
          # bnc#594482 - grub config not using uuid
          # if there is "not created" partition and flag for "it" is not set
          if partition["create"] && Yast::Mode.installation
            @proposed_partition = partition["device"] || "" if @proposed_partition == ""
            @all_devices_created = 1
          end

          map_partitions(partition, partition["device"])
        end
      end
      if Yast::Mode.installation && @all_devices_created == 2
        @all_devices_created = 0
        log.info("set status for all_devices to \"created\"")
      end
      log.debug("device name mapping to kernel names: #{@all_devices}")

      @target_map_timestamp = Yast::Storage.GetTargetChangeTime
      if Yast::Mode.installation
        @partitions_created ||= !partition_not_yet_created?
      end

      nil
    end

    def cache_valid?
      return false unless @all_devices

      # bnc#594482 - grub config not using uuid
      # if there is "not created" partition and flag for "it" is not set
      if Yast::Mode.installation
        already_created = !partition_not_yet_created?
        return false if already_created != @partitions_created
      end

      return @target_map_timestamp == Yast::Storage.GetTargetChangeTime
    end

    def partition_not_yet_created?
      Yast::Storage.GetTargetMap.values.any? do |disk|
        (disk["partitions"] || []).any? { |p| p["create"] }
      end
    end
  end
end
