require "yast"
require "singleton"

Yast.import "Storage"
Yast.import "Mode"

module Bootloader
  class DeviceMapping
    include Singleton
    include Yast::Logger

    # make more comfortable to work with singleton
    class << self
      extend Forwardable
      def_delegators :instance, :to_hash, :recreate_mapping, :to_kernel_device
    end

    # TODO remove when remove pbl support
    def to_hash
      ensure_mapping_exists
      @all_devices
    end

    def to_kernel_device(dev)
      return dev if dev !~ /^\/dev\/disk\/by-/

      ensure_mapping_exists

      @all_devices[dev] or raise "Unknown udev device #{dev}"
    end

    # FIXME Temporary method, will be removed as class itself recognize cache invalidation
    def recreate_mapping
      map_devices
    end
  private

    def ensure_mapping_exists
      map_devices if !@all_devices
    end



    DISK_UDEV_MAPPING = {
      "uuid"      => "/dev/disk/by-uuid/",
      "udev_id"   => "/dev/disk/by-id/",
      "udev_path" => "/dev/disk/by-path/",
    }

    PART_UDEV_MAPPING = DISK_UDEV_MAPPING.merge({
      "label"     => "/dev/disk/by-label/"
    })

    # Maps udev names to kernel names with given mapping from data to device
    # @private internall use only
    # @note only temporary method
    def map_devices_for_mapping(mapping, data, device)
      mapping.each_pair do |key, prefix|
        names = data[key]
        next if [nil, "", []].include?(names)
        names = [names] if names.is_a?(::String)
        names.each do |name|
          # watch out for fake uuids (shorter than 9 chars)
          next if name.size < 9 && key == "uuid"
          @all_devices[prefix + name] = device
        end
      end
    end

    # FATE #302219 - Use and choose persistent device names for disk devices
    # Function prepare maps with mapping disks and partitions by uuid, id, path
    # and label.
    #
    def map_devices
      @all_devices = {}
      Yast::Storage.GetTargetMap.each_pair do |device, value|
        map_devices_for_mapping(DISK_UDEV_MAPPING, value, device)

        next unless value["partitions"]

        value["partitions"].each do |partition|
          # bnc#594482 - grub config not using uuid
          # if there is "not created" partition and flag for "it" is not set
          if partition["create"] && Yast::Mode.installation
            @proposed_partition = partition["device"] || "" if @proposed_partition == ""
            @all_devices_created = 1
          end

          map_devices_for_mapping(PART_UDEV_MAPPING, partition, partition["device"])
        end
      end
      if Yast::Mode.installation && @all_devices_created == 2
        @all_devices_created = 0
        log.info("set status for all_devices to \"created\"")
      end
      log.debug("device name mapping to kernel names: #{@all_devices}")

      nil
    end
  end
end
