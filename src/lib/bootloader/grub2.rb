# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/mbr_update"
require "bootloader/device_map_dialog"
require "bootloader/stage1"

Yast.import "Arch"
Yast.import "BootStorage"
Yast.import "Storage"
Yast.import "BootCommon"
Yast.import "HTML"

module Bootloader
  # Represents non-EFI variant of GRUB2
  class Grub2 < GRUB2Base
    def initialize
      super

      textdomain "bootloader"
    end

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    def read(reread: false)
      BootStorage.device_map.propose if BootStorage.device_map.empty?

      super
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def write
      # TODO: device map write
      # TODO: install_dev write

      # something with PMBR needed
      # TODO: own class handling PBMR
      if BootCommon.pmbr_action
        boot_devices = BootCommon.GetBootloaderDevices
        boot_discs = boot_devices.map { |d| Storage.GetDisk(Storage.GetTargetMap, d) }
        boot_discs.uniq!
        gpt_disks = boot_discs.select { |d| d["label"] == "gpt" }
        gpt_disks_devices = gpt_disks.map { |d| d["device"] }

        pmbr_setup(BootCommon.pmbr_action, *gpt_disks_devices)
      end

      super
    end

    def propose
      super

      # TODO: propose install_device file
      # TODO: propose device map
    end

    # FATE#303643 Enable one-click changes in bootloader proposal
    #
    #
    def url_location_summary
      # TODO: convert to using grub_devices info
      Builtins.y2milestone("Prepare url summary for GRUB2")
      line = "<ul>\n<li>"
      if BootCommon.globals["boot_mbr"] == "true"
        line << _(
          "Install bootcode into MBR (<a href=\"disable_boot_mbr\">do not install</a>)"
        )
      else
        line << _(
          "Do not install bootcode into MBR (<a href=\"enable_boot_mbr\">install</a>)"
        )
      end
      line << "</li>\n"

      # do not allow to switch on boot from partition that do not support it
      if BootStorage.can_boot_from_partition
        line << "<li>"

        # check for separated boot partition, use root otherwise
        if BootStorage.BootPartitionDevice != BootStorage.RootPartitionDevice
          if BootCommon.globals["boot_boot"] == "true"
            line << _(
              "Install bootcode into /boot partition (<a href=\"disable_boot_boot\">do not install</a>)"
            )
          else
            line << _(
              "Do not install bootcode into /boot partition (<a href=\"enable_boot_boot\">install</a>)"
            )
          end
        else
          if BootCommon.globals["boot_root"] == "true"
            line << _(
              "Install bootcode into \"/\" partition (<a href=\"disable_boot_root\">do not install</a>)"
            )
          else
            line << _(
              "Do not install bootcode into \"/\" partition (<a href=\"enable_boot_root\">install</a>)"
            )
          end
        end
        line << "</li>"
      end

      if ["boot_root", "boot_boot", "boot_mbr", "boot_extended"].none? { |loc| BootCommon.globals[loc] == "true" } &&
          (BootCommon.globals["boot_custom"].nil? || BootCommon.globals["boot_custom"].empty?)
        # no location chosen, so warn user that it is problem unless he is sure
        msg = _("Warning: No location for bootloader stage1 selected." \
          "Unless you know what you are doing please select above location.")
        line << "<li>" << HTML.Colorize(msg, "red") << "</li>"
      end

      line << "</ul>"

      # TRANSLATORS: title for list of location proposals
      _("Change Location: %s") % line
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary
      # TODO: convert to using grub_devices info
      result = [
        Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2"
        )
      ]
      locations = []

      if BootCommon.globals["boot_boot"] == "true"
        locations << BootStorage.BootPartitionDevice + " (\"/boot\")"
      end
      if BootCommon.globals["boot_extended"] == "true"
        # TRANSLATORS: extended is here for extended partition. Keep translation short.
        locations << BootStorage.ExtendedPartitionDevice + _(" (extended)")
      end
      if BootCommon.globals["boot_root"] == "true"
        locations << BootStorage.RootPartitionDevice + " (\"/\")"
      end
      if BootCommon.globals["boot_mbr"] == "true"
        # TRANSLATORS: MBR is acronym for Master Boot Record, if nothing locally specific
        # is used in your language, then keep it as it is.
        locations << BootCommon.mbrDisk + _(" (MBR)")
      end
      if BootCommon.globals["boot_custom"] && !BootCommon.globals["boot_custom"].empty?
        locations << BootCommon.globals["boot_custom"]
      end
      if !locations.empty?
        result << Builtins.sformat(
          _("Status Location: %1"),
          locations.join(", ")
        )
      end

      # it is necessary different summary for autoyast and installation
      # other mode than autoyast on running system
      # both ppc and s390 have special devices for stage1 so it do not make sense
      # allow change of location to MBR or boot partition (bnc#879107)
      result << url_location_summary if !Arch.ppc && !Arch.s390 && !Mode.config

      order_sum = BootCommon.DiskOrderSummary
      result << order_sum if order_sum

      result
    end

    def name
      "grub2"
    end
  end
end
