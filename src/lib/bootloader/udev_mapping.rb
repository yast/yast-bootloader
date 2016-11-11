require "yast"
require "singleton"

require "bootloader/exceptions"

Yast.import "Storage"
Yast.import "Mode"
Yast.import "Arch"

module Bootloader
  # Class manages mapping between udev names of disks and partitions.
  class UdevMapping
    include Singleton
    include Yast::Logger
    include Yast::I18n

    # make more comfortable to work with singleton
    class << self
      extend Forwardable
      def_delegators :instance,
        :to_kernel_device,
        :to_mountby_device
    end

    # Converts full udev name to kernel device ( disk or partition )
    # @param dev [String] device udev, mdadm or kernel name like /dev/disk/by-id/blabla
    # @raise when device have udev format but do not exists
    # @return [String,nil] kernel device or nil when running AutoYaST configuration.
    def to_kernel_device(dev)
      textdomain "bootloader"
      log.info "call to_kernel_device for #{dev}"
      raise "invalid device nil" unless dev

      # for non-udev devices try to see specific raid names (bnc#944041)
      if dev =~ /^\/dev\/disk\/by-/
        udev_to_kernel(dev)
      else
        alternative_raid_to_kernel(dev)
      end
    end

    # Converts udev or kernel device (disk or partition) to udev name according to mountby
    # option or kernel device if such udev device do not exists
    # @param dev [String] device udev or kernel one like /dev/disk/by-id/blabla
    # @raise when device have udev format but do not exists
    # @return [String] udev name
    def to_mountby_device(dev)
      kernel_dev = to_kernel_device(dev)

      log.info "#{dev} looked as kernel device name: #{kernel_dev}"

      storage_data = storage_data_for(kernel_dev)
      return kernel_dev unless storage_data

      mount_by = used_mount_by(storage_data)
      # explicit request to mount by kernel device
      return kernel_dev if mount_by == :device

      disk = Yast::Storage.GetTargetMap.key?(kernel_dev)
      if disk && mount_by == :label
        log.info "mount by label for disk, so using kernel device as fallback"
        return kernel_dev
      end

      udev_data_key = MOUNT_BY_MAPPING_TO_UDEV[mount_by]
      raise "Internal error unknown mountby #{mount_by}" unless udev_data_key
      udev_pair = map_device_to_udev_devices(
        storage_data[udev_data_key],
        udev_data_key,
        kernel_dev
      ).first
      if !udev_pair
        log.warn "Cannot find udev link to satisfy mount by for #{kernel_dev}"
        return kernel_dev
      end

      # udev pair contain as first udev device and as second coresponding kernel device
      udev_pair.first
    end

  private

    def udev_to_kernel(dev)
      return all_devices[dev] if all_devices[dev]

      # in mode config if not found, then return itself
      return dev if Yast::Mode.config

      # TRANSLATORS: error message, %s stands for problematic device.
      raise(Bootloader::BrokenConfiguration, _("Unknown udev device '%s'") % dev)
    end

    def alternative_raid_to_kernel(dev)
      param = Yast::ArgRef.new({})
      result = Yast::Storage.GetContVolInfo(dev, param)
      return dev unless result # not raid with funny name

      info = param.value
      return info["vdevice"] unless info["vdevice"].empty?
      return info["cdevice"] unless info["cdevice"].empty?

      raise "unknown value for raid device '#{info.inspect}'"
    end

    def storage_data_for(kernel_dev)
      # we do not know if it is partition or disk, but target map help us
      target_map = Yast::Storage.GetTargetMap
      storage_data = target_map[kernel_dev]
      if !storage_data # so partition
        disk = target_map[Yast::Storage.GetDiskPartition(kernel_dev)["disk"]]
        # if device is not disk, then it can be virtual device like tmpfs or
        # disk no longer exists, so just return nil and kernel dev above
        return nil unless disk

        storage_data = disk["partitions"].find do |p|
          [p["device"], p["crypt_device"]].include?(kernel_dev)
        end
      end

      storage_data
    end

    def used_mount_by(storage_data)
      mount_by = storage_data["mountby"]
      mount_by ||= Yast::Arch.ppc ? :id : Yast::Storage.GetDefaultMountBy

      log.info "mount by: #{mount_by}"

      mount_by
    end

    # reader of all devices that ensure that it contain valid data
    #
    # @return hash where keys are udev links for disks and partitions and value
    #   their kernel devices.
    #
    # @example of output
    #   {
    #     "/dev/disk/by-id/abcd" => "/dev/sda",
    #     "/dev/disk/by-id/abcde" => "/dev/sda",
    #     "/dev/disk/by-label/label1" => "/dev/sda1",
    #     "/dev/disk/by-uuid/aaaa-bbbb-cccc-dddd" => "/dev/sda",
    def all_devices
      map_devices unless cache_valid?
      @all_devices
    end

    # Maps mountby symbol to udev key in Storage target map
    MOUNT_BY_MAPPING_TO_UDEV = {
      uuid:  "uuid",
      id:    "udev_id",
      path:  "udev_path",
      label: "label"
    }.freeze

    # Maps udev key in Storage target map to device prefix
    UDEV_MAPPING = {
      "uuid"      => "/dev/disk/by-uuid/",
      "udev_id"   => "/dev/disk/by-id/",
      "udev_path" => "/dev/disk/by-path/",
      "label"     => "/dev/disk/by-label/"
    }.freeze

    # Maps udev names to kernel names with given mapping from data to device
    # @private internall use only
    # @note only temporary method
    def map_disks(data, device)
      keys = UDEV_MAPPING.keys - ["label"] # disks do not have labels
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

    # Returns array of pairs where each pair contain full udev name as first and kernel
    # device as second
    # @param names [Array<String>] udev names for device e.g. "aaaa-bbbb-cccc-dddd"
    #   for uuid device name
    # @param key [String] storage key for given udev mapping see UDEV_MAPPING
    # @param device [String] kernel name e.g. "/dev/sda"
    # @example
    #   map_device_to_udev_devices(["aaaa-bbbb-cccc-dddd"], "uuid", "/dev/sda")
    #   => [["/dev/disk/by-uuid/aaaa-bbbb-cccc-dddd", "/dev/sda"]]
    def map_device_to_udev_devices(names, key, device)
      return [] if [nil, "", []].include?(names)
      prefix = UDEV_MAPPING[key]
      names = [names] if names.is_a?(::String)
      names.reduce([]) do |res, name|
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
          map_partitions(partition, partition["device"])
        end
      end
      log.debug("device name mapping to kernel names: #{@all_devices}")

      @target_map_timestamp = Yast::Storage.GetTargetChangeTime
      @uuids_stable = !uuid_may_appear? if Yast::Mode.installation

      nil
    end

    def cache_valid?
      return false unless @all_devices

      # bnc#594482 - check if cache do not contain final uuids and recreate it when it is stable
      if Yast::Mode.installation && !@uuids_stable
        # recreate cache if uuids are stable now
        return false unless uuid_may_appear?
      end

      @target_map_timestamp == Yast::Storage.GetTargetChangeTime
    end

    def uuid_may_appear?
      # uuid is not known until fs is created see bnc#594482
      Yast::Storage.GetTargetMap.values.any? do |disk|
        (disk["partitions"] || []).any? { |p| p["create"] }
      end
    end
  end
end
