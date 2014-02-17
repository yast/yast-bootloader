# encoding: utf-8
require "yast"

module Yast
  class GRUB2Base < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "BootArch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Pkg"
      Yast.import "HTML"
      Yast.import "Initrd"
      Yast.import "Product"

      # includes
      # for simplified widgets than other
      Yast.include self, "bootloader/grub2/dialogs.rb"
    end

    # general functions

    # Propose global options of bootloader
    def StandardGlobals
      {
        "timeout"   => "8",
        "default"   => "0",
        "vgamode"   => "",
        "gfxmode"   => "auto",
        "terminal"  => "gfxterm",
        "os_prober" => "true"
      }
    end

    # Update read settings to new version of configuration files
    def Update
      Read(true, true)

      #we don't handle sections, grub2 section create them for us
      #BootCommon::UpdateSections ();
      BootCommon.UpdateGlobals

      nil
    end

    # Reset bootloader settings
    # @param [Boolean] init boolean true to repropose also device map
    def Reset(init)
      return if Mode.autoinst
      BootCommon.Reset(init)

      nil
    end

    def Dialogs
      Builtins.y2milestone("Called GRUB2 Dialogs")
      {
        "installation" => fun_ref(
          method(:Grub2InstallDetailsDialog),
          "symbol ()"
        ),
        "loader"       => fun_ref(
          method(:Grub2LoaderDetailsDialog),
          "symbol ()"
        )
      }
    end

    # Initializer of GRUB bootloader
    def Initializer
      Builtins.y2milestone("Called GRUB2 initializer")
      BootCommon.current_bootloader_attribs = {
        "propose"            => false,
        "read"               => false,
        "scratch"            => false,
        "restore_mbr"        => false,
        "bootloader_on_disk" => false
      }

      nil
    end
  end
end
