# encoding: utf-8

# File:
#      modules/BootGRUB2EFI.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB2EFI configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id: BootGRUB2EFI.ycp 63508 2011-03-04 12:53:27Z jreidinger $
#
require "yast"
require "bootloader/grub2base"

module Yast
  class BootGRUB2EFIClass < GRUB2Base
    def main
      super

      textdomain "bootloader"
      BootGRUB2EFI()
    end

    # general functions

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "grub2-efi")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      BootCommon.Read(false, avoid_reading_device_map)
      # read status of secure boot to boot common cache (bnc#892032)
      BootCommon.getSystemSecureBootStatus(reread)
      @orig_globals ||= deep_copy(BootCommon.globals)
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader

      # we do not have originals or it changed
      if !@orig_globals ||
          @orig_globals["distributor"] != BootCommon.globals["distributor"]
        BootCommon.location_changed = true
      end

      if BootCommon.location_changed
        grub_ret = BootCommon.InitializeBootloader
        grub_ret = false if grub_ret.nil?

        Builtins.y2milestone("GRUB2EFI return value: %1", grub_ret)
        ret = ret && grub_ret
      end

      # something with PMBR needed
      if BootCommon.pmbr_action
        efi_disk = Storage.GetEntryForMountpoint("/boot/efi")["device"]
        efi_disk ||= Storage.GetEntryForMountpoint("/boot")["device"]
        efi_disk ||= Storage.GetEntryForMountpoint("/")["device"]

        pmbr_setup(BootCommon.pmbr_action, efi_disk)
      end

      ret
    end

    def Propose
      super

      # for UEFI always set PMBR flag on disk (bnc#872054)
      BootCommon.pmbr_action = :add if !BootCommon.was_proposed || Mode.autoinst || Mode.autoupgrade

      # set secure boot always on (bnc #879486)
      BootCommon.setSystemSecureBootStatus(true) if !BootCommon.was_proposed && Arch.x86_64;
    end

    # Display bootloader summary
    # @return a list of summary lines

    def Summary
      result = [
        Builtins.sformat(
          _("Boot Loader Type: %1"),
          BootCommon.getLoaderName(BootCommon.getLoaderType(false), :summary)
        )
      ]

      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Enable Secure Boot: %1"),
          BootCommon.getSystemSecureBootStatus(false)
        )
      )
      deep_copy(result)
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write":BootGRUB2EFI::Write])
    def GetFunctions
      {
        "read"    => fun_ref(method(:Read), "boolean (boolean, boolean)"),
        "reset"   => fun_ref(method(:Reset), "void (boolean)"),
        "propose" => fun_ref(method(:Propose), "void ()"),
        "save"    => fun_ref(method(:Save), "boolean (boolean, boolean, boolean)"),
        "summary" => fun_ref(method(:Summary), "list <string> ()"),
        "update"  => fun_ref(method(:Update), "void ()"),
        "widgets" => fun_ref(
          method(:grub2efiWidgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs" => fun_ref(method(:Dialogs), "map <string, symbol ()> ()"),
        "write"   => fun_ref(method(:Write), "boolean ()")
      }
    end

    # Constructor
    def BootGRUB2EFI
      if Arch.i386
        packages = ["grub2-i386-efi"]
      elsif Arch.x86_64
        packages = ["grub2-x86_64-efi", "shim", "mokutil"]
      else
        # do not raise exception as we call constructor everywhere even if it doesn't make sense
        packages = []
      end

      Ops.set(
        BootCommon.bootloader_attribs,
        "grub2-efi",
        
        "required_packages" => packages,
        "loader_name"       => "GRUB2-EFI",
        "initializer"       => fun_ref(method(:Initializer), "void ()")
        
      )

      nil
    end

    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :variable => :grub_help_messages, :type => "map <string, string>"
    publish :variable => :grub_descriptions, :type => "map <string, string>"
    publish :variable => :grub2_help_messages, :type => "map <string, string>"
    publish :variable => :grub2_descriptions, :type => "map <string, string>"
    publish :variable => :password, :type => "string"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :grub2Widgets, :type => "map <string, map <string, any>> ()"
    publish :function => :grub2efiWidgets, :type => "map <string, map <string, any>> ()"
    publish :function => :StandardGlobals, :type => "map <string, string> ()"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootGRUB2EFI, :type => "void ()"
  end

  BootGRUB2EFI = BootGRUB2EFIClass.new
  BootGRUB2EFI.main
end
