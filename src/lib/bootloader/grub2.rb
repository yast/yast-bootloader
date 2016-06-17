# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/mbr_update"
require "bootloader/device_map"
require "bootloader/stage1"
require "bootloader/grub_install"

Yast.import "Arch"
Yast.import "BootStorage"
Yast.import "Storage"
Yast.import "HTML"

module Bootloader
  # Represents non-EFI variant of GRUB2
  class Grub2 < Grub2Base
    attr_reader :stage1
    attr_reader :device_map
    # @return [Boolean]
    attr_accessor :trusted_boot

    def initialize
      super

      textdomain "bootloader"
      @stage1 = Stage1.new
      @grub_install = GrubInstall.new(efi: false)
      @device_map = DeviceMap.new
      @trusted_boot = false
    end

    # Read settings from disk, overwritting already set values
    def read
      super

      begin
        stage1.read
      rescue Errno::ENOENT
        # grub_installdevice is not part of grub2 rpm, so it doesn't need to exist.
        # In such case ignore exception and use empty @stage1
        log.info "grub_installdevice does not exist. Using empty one."
        @stage1 = Stage1.new
      end

      begin
        # device map is needed only for legacy boot on intel
        device_map.read if Yast::Arch.x86_64 || Yast::Arch.i386
      rescue Errno::ENOENT
        # device map is only optional part of grub2, so it doesn't need to exist.
        # In such case ignore exception and use empty device map
        log.info "grub2/device.map does not exist. Using empty one."
        @device_map = DeviceMap.new
      end

      @trusted_boot = Sysconfig.from_system.trusted_boot
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def write
      # super have to called as first as grub install require some config writen in ancestor
      super

      device_map.write if Yast::Arch.x86_64 || Yast::Arch.i386
      stage1.write

      # TODO: own class handling PBMR
      pmbr_setup(*gpt_disks_devices)

      # powernv must not call grub2-install (bnc#970582)
      unless Yast::Arch.board_powernv
        @grub_install.execute(devices: stage1.devices, trusted_boot: trusted_boot)
      end
      # Do some mbr activations ( s390 do not have mbr nor boot flag on its disks )
      # powernv do not have prep partition, so we do not have any partition to activate (bnc#970582)
      MBRUpdate.new.run(stage1) if !Yast::Arch.s390 && !Yast::Arch.board_powernv
    end

    def propose
      super

      stage1.propose
      # for GPT add protective MBR flag otherwise some systems won't
      # boot, safer option for legacy booting (bnc#872054)
      self.pmbr_action = :add if Yast::BootStorage.gpt_boot_disk?
      device_map.propose if Yast::Arch.x86_64 || Yast::Arch.i386
      @trusted_boot = false
    end

    def merge(other)
      super

      @device_map = other.device_map if !other.device_map.empty?
      @trusted_boot = other.trusted_boot unless other.trusted_boot.nil?

      stage1.merge(other.stage1)
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2"
        ),
        Yast::Builtins.sformat(
          _("Enable Trusted Boot: %1"),
          @trusted_boot ? _("yes") : _("no")
        )
      ]
      locations_val = locations
      if !locations_val.empty?
        result << Yast::Builtins.sformat(
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

    def packages
      res = super

      res << "grub2"

      if stage1.generic_mbr?
        # needed for generic _mbr binary files
        res << "syslinux"
      end

      if Yast::Arch.x86_64 || Yast::Arch.i386
        res << "trustedgrub2" << "trustedgrub2-i386-pc" if @trusted_boot
      end

      res
    end

    # FIXME: refactor with injection like super(prewrite: prewrite, sysconfig = ...)
    # overwrite BootloaderBase version to save trusted boot
    def write_sysconfig(prewrite: false)
      sysconfig = Bootloader::Sysconfig.new(bootloader: name, trusted_boot: @trusted_boot)
      prewrite ? sysconfig.pre_write : sysconfig.write
    end

  private

    def gpt_disks_devices
      boot_devices = stage1.devices
      boot_discs = boot_devices.map { |d| Yast::Storage.GetDisk(Yast::Storage.GetTargetMap, d) }
      boot_discs.uniq!
      gpt_disks = boot_discs.select { |d| d["label"] == "gpt" }
      gpt_disks.map { |d| d["device"] }
    end

    def disk_order_summary
      return "" if Yast::Arch.s390

      return "" if device_map.size < 2

      Yast::Builtins.sformat(
        # part of summary, %1 is a list of hard disks device names
        _("Order of Hard Disks: %1"),
        device_map.disks_order.join(", ")
      )
    end

    def locations
      locations = []

      partition_location = boot_partition_location
      locations << partition_location unless partition_location.empty?
      if stage1.extended_partition? && Yast::BootStorage.ExtendedPartitionDevice
        # TRANSLATORS: extended is here for extended partition. Keep translation short.
        locations << Yast::BootStorage.ExtendedPartitionDevice + _(" (extended)")
      end
      if stage1.mbr? && Yast::BootStorage.mbr_disk
        # TRANSLATORS: MBR is acronym for Master Boot Record, if nothing locally specific
        # is used in your language, then keep it as it is.
        locations << Yast::BootStorage.mbr_disk + _(" (MBR)")
      end
      locations << stage1.custom_devices if !stage1.custom_devices.empty?

      locations
    end

    def boot_partition_location
      if Yast::BootStorage.separated_boot?
        if stage1.boot_partition?
          return Yast::BootStorage.BootPartitionDevice + " (\"/boot\")"
        end
      else
        if stage1.root_partition?
          return Yast::BootStorage.RootPartitionDevice + " (\"/\")"
        end
      end

      ""
    end

    def mbr_line
      if stage1.mbr?
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
      if Yast::BootStorage.separated_boot?
        if stage1.boot_partition?
          _(
            "Install bootcode into /boot partition " \
              "(<a href=\"disable_boot_boot\">do not install</a>)"
          )
        else
          _(
            "Do not install bootcode into /boot partition " \
              "(<a href=\"enable_boot_boot\">install</a>)"
          )
        end
      else
        if stage1.root_partition?
          _(
            "Install bootcode into \"/\" partition " \
              "(<a href=\"disable_boot_root\">do not install</a>)"
          )
        else
          _(
            "Do not install bootcode into \"/\" partition " \
              "(<a href=\"enable_boot_root\">install</a>)"
          )
        end
      end
    end

    # FATE#303643 Enable one-click changes in bootloader proposal
    #
    #
    def url_location_summary
      log.info "Prepare url summary for GRUB2"
      line = "<ul>\n<li>"
      line << mbr_line
      line << "</li>\n"

      # do not allow to switch on boot from partition that do not support it
      if stage1.can_use_boot?
        line << "<li>"
        line << partition_line
        line << "</li>"
      end

      if stage1.devices.empty?
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
