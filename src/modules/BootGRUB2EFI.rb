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

module Yast
  class BootGRUB2EFIClass < Module
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
      # for shared some routines with grub
      # include "bootloader/grub/misc.ycp";
      # for simplified widgets than other
      Yast.include self, "bootloader/grub2/dialogs.rb"
      BootGRUB2EFI()
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

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "grub2-efi")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      # TODO: check if necessary for grub2efi
      # grub_DetectDisks ();
      ret = BootCommon.Read(false, avoid_reading_device_map)

      # TODO: check if necessary for grub2
      # refresh device map if not read
      # if (BootStorage::device_mapping == nil
      #    || size (BootStorage::device_mapping) == 0)
      # {
      #    BootStorage::ProposeDeviceMap ();
      # }

      ret
    end

    # Update read settings to new version of configuration files
    def Update
      Read(true, true)

      #we don't handle sections, grub2 section create them for us
      #BootCommon::UpdateSections ();
      BootCommon.UpdateGlobals

      nil
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader

      if BootCommon.location_changed
        grub_ret = BootCommon.InitializeBootloader
        grub_ret = false if grub_ret == nil

        Builtins.y2milestone("GRUB2EFI return value: %1", grub_ret)
        ret = ret && grub_ret
      end

      ret
    end

    # Reset bootloader settings
    # @param [Boolean] init boolean true to repropose also device map
    def Reset(init)
      return if Mode.autoinst
      BootCommon.Reset(init)

      nil
    end

    # Propose bootloader settings

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

      if BootCommon.globals == nil || Builtins.size(BootCommon.globals) == 0
        BootCommon.globals = StandardGlobals()
      else
        BootCommon.globals = Convert.convert(
          Builtins.union(BootCommon.globals, StandardGlobals()),
          :from => "map",
          :to   => "map <string, string>"
        )
      end

      swap_sizes = BootCommon.getSwapPartitions
      swap_parts = Builtins.maplist(swap_sizes) { |name, size| name }
      swap_parts = Builtins.sort(swap_parts) do |a, b|
        Ops.greater_than(Ops.get(swap_sizes, a, 0), Ops.get(swap_sizes, b, 0))
      end

      largest_swap_part = Ops.get(swap_parts, 0, "")

      resume = BootArch.ResumeAvailable ? largest_swap_part : ""
      # try to use label or udev id for device name... FATE #302219
      if resume != "" && resume != nil
        resume = BootStorage.Dev2MountByDev(resume)
      end
      Ops.set(
        BootCommon.globals,
        "append",
        BootArch.DefaultKernelParams(resume)
      )
      Ops.set(
        BootCommon.globals,
        "append_failsafe",
        BootArch.FailsafeKernelParams
      )
      Ops.set(
        BootCommon.globals,
        "distributor",
        Ops.add(Ops.add(Product.short_name, " "), Product.version)
      )
      BootCommon.kernelCmdLine = Kernel.GetCmdLine

      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals) 

      # Let grub2 scripts detects correct root= for us. :)
      # BootCommon::globals["root"] = BootStorage::Dev2MountByDev(BootStorage::RootPartitionDevice);

      # We don't set vga= if Grub2 gfxterm enabled, because the modesettings
      # will be delivered to kernel by Grub2's gfxpayload set to "keep"
      #if (BootArch::VgaAvailable () && Kernel::GetVgaType () != "")
      #{
      #    BootCommon::globals["vgamode"] = Kernel::GetVgaType ();
      #}

      nil
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

    def Dialogs
      Builtins.y2milestone("Called GRUB2 Dialogs")
      { "loader" => fun_ref(method(:Grub2LoaderDetailsDialog), "symbol ()") }
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write":BootGRUB2EFI::Write])
    def GetFunctions
      {
        "read"    => fun_ref(method(:Read), "boolean (boolean, boolean)"),
        "reset"   => fun_ref(method(:Reset), "void (boolean)"),
        "propose" => fun_ref(method(:Propose), "void ()"),
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


    # Initializer of GRUB2EFI bootloader
    def Initializer
      Builtins.y2milestone("Called GRUB2EFI initializer")
      BootCommon.current_bootloader_attribs = {
        "propose"            => false,
        "read"               => false,
        "scratch"            => false,
        "restore_mbr"        => false,
        "bootloader_on_disk" => false
      }

      nil
    end

    # Constructor
    def BootGRUB2EFI
      Ops.set(
        BootCommon.bootloader_attribs,
        "grub2-efi",
        {
          "required_packages" => ["grub2-efi", "shim"],
          "loader_name"       => "GRUB2-EFI",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :variable => :grub_help_messages, :type => "map <string, string>"
    publish :variable => :grub_descriptions, :type => "map <string, string>"
    publish :variable => :grub2_help_messages, :type => "map <string, string>"
    publish :variable => :grub2_descriptions, :type => "map <string, string>"
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
