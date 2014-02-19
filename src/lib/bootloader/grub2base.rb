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

    def Propose
      if BootCommon.was_proposed
        # workaround autoyast config is Imported thus was_proposed always set
        if Mode.autoinst
          Builtins.y2milestone(
            "autoinst mode we ignore meaningless was_proposed as it always set"
          )
        else
          Builtins.y2milestone(
            "calling Propose with was_proposed set is really bogus, clear it to force a re-propose"
          )
          return
        end
      end


      if BootCommon.globals == nil || BootCommon.globals.empty?
        BootCommon.globals = StandardGlobals()
      else
        BootCommon.globals |= StandardGlobals()
      end

      swap_parts = BootCommon.getSwapPartitions
      largest_swap_part = swap_parts.max_by{|part, size| size}.first || ""

      resume = BootArch.ResumeAvailable ? largest_swap_part : ""
      # try to use label or udev id for device name... FATE #302219
      if resume != "" && resume != nil
        resume = BootStorage.Dev2MountByDev(resume)
      end

      BootCommon.globals["append"]          = BootArch.DefaultKernelParams(resume)
      BootCommon.globals["append_failsafe"] = BootArch.FailsafeKernelParams
      BootCommon.globals["distributor"]     = Product.name
      BootCommon.kernelCmdLine              = Kernel.GetCmdLine

      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
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
