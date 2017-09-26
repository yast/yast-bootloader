require "yast"
require "singleton"

require "bootloader/exceptions"
require "y2storage"

Yast.import "Mode"

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

    # Converts udev or kernel device (disk or partition) to udev name that fits best.
    #
    # Here is description of strategy for finding the best possible udev persistent name.
    # There are three scenarios we consider:
    # S1. disk with boot configuration is moved to different PC
    # S2. disk dies and its content is loaded to new disk from backup
    # S3. path to disk dies and disk is moved to different one
    #
    # Strategy is:
    #
    # 1. if device have filesystem and it have its mount_by, then respect it
    # 2. if there is by-label use it, as it allows to handle S1, S2 and S3 just with using same
    #    label
    # 3. if there is by-uuid then use it as it can also handle S1, S2 and S3 as uuid can be
    #    changed, but it is harder to do
    # 4. if there is by-id use it, as it can handle S3 in some scenarios, but not always.
    # 5. if there is by-path use it as it is last supported udev symlink that at least prevent
    #    change of kernel device during boot
    # 6. as fallback use kernel name
    #
    # @param dev [String] device udev or kernel one like /dev/disk/by-id/blabla
    # @raise when device have udev format but do not exists
    # @return [String] udev name
    def to_mountby_device(dev)
      kernel_dev = to_kernel_device(dev)

      log.info "#{dev} looked as kernel device name: #{kernel_dev}"

      kernel_to_udev(kernel_dev)
    end

  private

    def staging
      Y2Storage::StorageManager.instance.staging
    end

    def udev_to_kernel(dev)
      # in mode config if not found, then return itself
      return dev if Yast::Mode.config

      devices = Y2Storage::BlkDevice.all(staging)
      devices.reject! { |d| d.is?(:disk) && d.descendants.any? { |i| i.is?(:multipath) } }
      device = devices.find { |i| i.udev_full_all.include?(dev) }
      return device.name if device

      # TRANSLATORS: error message, %s stands for problematic device.
      raise(Bootloader::BrokenConfiguration, _("Unknown udev device '%s'") % dev)
    end

    def kernel_to_udev(dev)
      device = Y2Storage::BlkDevice.find_by_name(staging, dev)
      if device.nil?
        log.error "Cannot find #{dev}"
        return dev
      end

      result = udev_name_for(device)
      log.info "udev device for #{dev.inspect} is #{result.inspect}"

      result
    end

    # picks udev name according to strategy
    # @see #to_mountby_device
    def udev_name_for(device)
      mount_by_udev(device) ||
        udev_by_label(device) ||
        udev_by_uuid(device) ||
        udev_by_id(device) ||
        udev_by_path(device) ||
        device.name
    end

    def mount_by_udev(device)
      filesystem = device.filesystem
      return nil unless filesystem

      case filesystem.mount_by.to_sym
      when :device then device.name
      when :uuid then udev_by_uuid(device)
      when :label then udev_by_label(device)
      when :id then udev_by_id(device)
      when :path then udev_by_path(device)
      else
        raise "Unknown mount by option #{filesystem.mount_by.inspect} for #{filesystem.inspect}"
      end
    end

    def udev_by_uuid(device)
      device.udev_full_uuid
    end

    def udev_by_label(device)
      device.udev_full_label
    end

    def udev_by_id(device)
      device.udev_full_ids.first
    end

    def udev_by_path(device)
      device.udev_full_paths.first
    end

    def alternative_raid_to_kernel(dev)
# storage-ng
# FIXME
# rubocop:disable Style/BlockComments
=begin
      param = Yast::ArgRef.new({})
      result = Yast::Storage.GetContVolInfo(dev, param)
      return dev unless result # not raid with funny name

      info = param.value
      return info["vdevice"] unless info["vdevice"].empty?
      return info["cdevice"] unless info["cdevice"].empty?

      raise "unknown value for raid device '#{info.inspect}'"
=end

      dev
    end
  end
end
