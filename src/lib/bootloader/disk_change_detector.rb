require "yast"

require "bootloader/udev_mapping"

module Bootloader
  # Task of this class is to detect if user change storage proposal
  # during installation, so bootloader configuration can be invalid.
  class DiskChangeDetector
    include Yast::I18n

    def initialize(stage1)
      Yast.import "BootStorage"
      Yast.import "Mode"

      textdomain "bootloader"
      @stage1 = stage1
    end

    # Check whether any disk settings for the disks we currently use were changed
    # so if any change is found, then configuration can be invalid
    # @return [Array<String>] list of localized messages with changes
    def changes
      return [] if Yast::Mode.config

      @stage1.model.devices.each_with_object([]) do |device, ret|
        next unless invalid_device?(device)

        # TRANSLATORS: %s stands for partition
        ret <<
          _("Selected bootloader partition %s is not available any more.") %
            device
      end
    end

  private

    def invalid_device?(device)
      all_boot_partitions = Yast::BootStorage.possible_locations_for_stage1

      !all_boot_partitions.include?(UdevMapping.to_kernel_device(device))
    end
  end
end
