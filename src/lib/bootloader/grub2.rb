# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/mbr_update"
require "bootloader/device_map_dialog"
require "bootloader/stage1"
require "bootloader/grub_install"

Yast.import "Arch"
Yast.import "BootStorage"
Yast.import "Storage"
Yast.import "HTML"

module Bootloader
  # Represents non-EFI variant of GRUB2
  class Grub2 < GRUB2Base
    attr_reader :stage1

    def initialize
      super

      textdomain "bootloader"
      @stage1 = Stage1.new
      @grub_install = GrubInstall.new(efi: false)
    end

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    def read(reread: false)
      Yast::BootStorage.device_map.propose if Yast::BootStorage.device_map.empty?
      @stage1.read

      super
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def write
      # TODO: device map write
      @stage1.write

      # TODO: own class handling PBMR
      boot_devices = @stage1.model.devices
      boot_discs = boot_devices.map { |d| Yast::Storage.GetDisk(Yast::Storage.GetTargetMap, d) }
      boot_discs.uniq!
      gpt_disks = boot_discs.select { |d| d["label"] == "gpt" }
      gpt_disks_devices = gpt_disks.map { |d| d["device"] }

      pmbr_setup(*gpt_disks_devices)

      @grub_install.execute(devices: @stage1.model.devices)
      # Do some mbr activations
      if !Yast::Arch.s390
        MBRUpdate.new.run(
          activate:      @stage1.activate,
          generic_mbr:   @stage1.generic_mbr,
          grub2_devices: @stage1
        )
      end

      super
    end

    def propose
      super

      @stage1.propose
      # for GPT remove protective MBR flag otherwise some systems won't
      # boot, safer option for legacy booting
      self.pmbr_action = :remove if Yast::BootStorage.gpt_boot_disk?

      # TODO: propose device map
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2"
        )
      ]
      locations_val = locations
      if !locations_val.empty?
        result << Builtins.sformat(
          _("Status Location: %1"),
          locations_val.join(", ")
        )
      end

      # it is necessary different summary for autoyast and installation
      # other mode than autoyast on running system
      # both ppc and s390 have special devices for stage1 so it do not make sense
      # allow change of location to MBR or boot partition (bnc#879107)
      result << url_location_summary if !Yast::Arch.ppc && !Yast::Arch.s390 && !Yast::Mode.config

      order_sum = disk_order_summary
      result << order_sum if order_sum

      result
    end

    def name
      "grub2"
    end

  private

    def disk_order_summary
      return "" if Yast::Arch.s390

      order = Yast::BootStorage.DisksOrder
      return "" if order.size < 2

      Yast::Builtins.sformat(
        # part of summary, %1 is a list of hard disks device names
        _("Order of Hard Disks: %1"),
        order.join(", ")
      )
    end

    def locations
      locations = []
      already_mentioned = []

      if Yast::BootStorage.BootPartitionDevice != Yast::BootStorage.RootPartitionDevice
        if @stage1.boot_partition?
          locations << Yast::BootStorage.BootPartitionDevice + " (\"/boot\")"
          already_mentioned << Yast::BootStorage.BootPartitionDevice
        end
      else
        if @stage1.root_partition?
          locations << Yast::BootStorage.RootPartitionDevice + " (\"/\")"
          already_mentioned << Yast::BootStorage.RootPartitionDevice
        end
      end
      if @stage1.extended_partition?
        # TRANSLATORS: extended is here for extended partition. Keep translation short.
        locations << Yast::BootStorage.ExtendedPartitionDevice + _(" (extended)")
        already_mentioned << Yast::BootStorage.ExtendedPartitionDevice
      end
      if @stage1.mbr?
        # TRANSLATORS: MBR is acronym for Master Boot Record, if nothing locally specific
        # is used in your language, then keep it as it is.
        locations << Yast::BootStorage.mbr_disk + _(" (MBR)")
        already_mentioned << Yast::BootStorage.mbr_disk
      end
      locations << @stage1.custom_devices if !@stage1.custom_devices.empty?

      locations
    end

    def mbr_line
      if @stage1.mbr?
        _(
          "Install bootcode into MBR (<a href=\"disable_boot_mbr\">do not install</a>)"
        )
      else
        _(
          "Do not install bootcode into MBR (<a href=\"enable_boot_mbr\">install</a>)"
        )
      end
    end

    def partition_line
      # check for separated boot partition, use root otherwise
      if Yast::BootStorage.BootPartitionDevice != Yast::BootStorage.RootPartitionDevice
        if @stage1.boot_partition?
          _(
            "Install bootcode into /boot partition (<a href=\"disable_boot_boot\">do not install</a>)"
          )
        else
          _(
            "Do not install bootcode into /boot partition (<a href=\"enable_boot_boot\">install</a>)"
          )
        end
      else
        if @stage1.root_partition?
          _(
            "Install bootcode into \"/\" partition (<a href=\"disable_boot_root\">do not install</a>)"
          )
        else
          _(
            "Do not install bootcode into \"/\" partition (<a href=\"enable_boot_root\">install</a>)"
          )
        end
      end
    end

    # FATE#303643 Enable one-click changes in bootloader proposal
    #
    #
    def url_location_summary
      # TODO: convert to using grub_devices info
      log.info "Prepare url summary for GRUB2"
      line = "<ul>\n<li>"
      line << mbr_line
      line << "</li>\n"

      # do not allow to switch on boot from partition that do not support it
      if Yast::BootStorage.can_boot_from_partition
        line << "<li>"
        line << partition_line
        line << "</li>"
      end

      if @stage1.model.devices.empty?
        # no location chosen, so warn user that it is problem unless he is sure
        msg = _("Warning: No location for bootloader stage1 selected." \
          "Unless you know what you are doing please select above location.")
        line << "<li>" << Yast::HTML.Colorize(msg, "red") << "</li>"
      end

      line << "</ul>"

      # TRANSLATORS: title for list of location proposals
      _("Change Location: %s") % line
    end
  end
end
