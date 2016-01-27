require "yast"

module Bootloader
  # Task of this class is to detect if user change storage proposal
  # during installation, so bootloader configuration can be invalid.
  class DiskChangeDetector
    include Yast::I18n

    def initialize
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Mode"
      Yast.import "Storage"

      textdomain "bootloader"

      mp = Yast::Storage.GetMountPoints
      @actual_root = mp["/"] ? mp["/"].first : ""
      @actual_boot = mp["/boot"] ? mp["/boot"].first : actual_root
      @actual_extended = Yast::BootStorage.extended_partition_for(Yast::BootStorage.BootPartitionDevice)
    end

    # Check whether any disk settings for the disks we currently use were changed
    # so if any change is found, then configuration can be invalid
    # @return [Array<String>] list of localized messages with changes
    def changes
      ret = []
      return ret if Yast::Mode.config

      if boot_changed?
        ret << change_message('"/boot"', Yast::BootStorage.BootPartitionDevice)
      end

      if root_changed?
        ret << change_message('"/"', Yast::BootStorage.RootPartitionDevice)
      end

      ret << change_message("MBR", Yast::BootStorage.mbr_disk) if mbr_changed?

      if extended_changed?
        ret << change_message('"extended partition"', Yast::BootStorage.ExtendedPartitionDevice)
      end

      if invalid_custom?
        # TRANSLATORS: %s stands for partition
        ret <<
          _("Selected custom bootloader partition %s is not available any more.") %
            Yast::BootCommon.globals["boot_custom"]
      end

      ret
    end

  private

    attr_reader :actual_boot, :actual_root, :actual_extended

    def change_message(location, device)
      # TRANSLATORS the %{path} is path where bootloader stage1 is selected to install and
      # the %{device} is device where it should be, but isn't
      _("Selected bootloader location %{path} is not on %{device} any more.") %
        { path: location, device: device }
    end

    def boot_changed?
      boot_selected?("boot_boot") &&
        actual_boot != Yast::BootStorage.BootPartitionDevice
    end

    def root_changed?
      boot_selected?("boot_root") &&
        actual_root != Yast::BootStorage.RootPartitionDevice
    end

    def mbr_changed?
      boot_selected?("boot_mbr") &&
        Yast::BootStorage.find_mbr_disk != Yast::BootStorage.mbr_disk
    end

    def extended_changed?
      boot_selected?("boot_extended") &&
        actual_extended != Yast::BootStorage.ExtendedPartitionDevice
    end

    def boot_selected?(key)
      Yast::BootCommon.globals[key] == "true"
    end

    def invalid_custom?
      boot_custom = Yast::BootCommon.globals["boot_custom"]
      return false if !boot_custom || boot_custom.empty?

      all_boot_partitions = Yast::BootStorage.possible_locations_for_stage1

      !all_boot_partitions.include?(boot_custom)
    end
  end
end
