# encoding: utf-8
require "yast"
require "bootloader/grub2pwd"
require "bootloader/udev_mapping"

module Yast
  # Common base for GRUB2 specialized classes
  class GRUB2Base < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootArch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "HTML"
      Yast.import "Initrd"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Pkg"
      Yast.import "Product"
      Yast.import "ProductFeatures"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "StorageDevices"

      # includes
      # for simplified widgets than other
      Yast.include self, "bootloader/grub2/dialogs.rb"

      # password can have three states
      # 1. nil -> remove password
      # 2. "" -> do not change it
      # 3. "something" -> set password to this value
      @password = ""
    end

    # general functions

    # set pmbr flags on boot disks
    def pmbr_setup(action, *devices)
      action_parted = case action
        when :add    then "on"
        when :remove then "off"
        else raise "invalid action #{action}"
        end
      devices.each do |dev|
        res = SCR.Execute(path(".target.bash_output"),
          "parted '#{dev}' disk_set pmbr_boot #{action_parted}")
        Builtins.y2milestone("parted disk_set pmbr: #{res}")
      end
    end

    # Propose global options of bootloader
    def StandardGlobals
      # s390 do not have os_prober, see bnc#868909#c2
      disable_os_prober = Arch.s390 || ProductFeatures.GetBooleanFeature("globals", "disable_os_prober")
      {
        "timeout"   => "8",
        "default"   => "0",
        "vgamode"   => "",
        "gfxmode"   => "auto",
        "terminal"  => Arch.s390 ? "console" : "gfxterm",
        "os_prober" => disable_os_prober ? "false" : "true",
        "activate"  => Arch.ppc ? "true" : "false"
      }
    end

    # Update read settings to new version of configuration files
    def Update
      Read(true, true)

      BootCommon.UpdateGlobals

      nil
    end

    # Reset bootloader settings
    # @param [Boolean] unused
    def Reset
      return if Mode.autoinst
      BootCommon.Reset
    end

    def Dialogs
      Builtins.y2milestone("Called GRUB2 Dialogs")
      {
        "loader"       => fun_ref(
          method(:Grub2LoaderDetailsDialog),
          "symbol ()"
        )
      }
    end

    def Propose
      if BootCommon.was_proposed
        # workaround autoyast config is Imported thus was_proposed always set
        if Mode.autoinst || Mode.autoupgrade
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

      BootCommon.globals = StandardGlobals().merge(BootCommon.globals || {})

      swap_parts = BootCommon.getSwapPartitions
      largest_swap_part = (swap_parts.max_by { |_part, size| size } || [""]).first

      resume = BootArch.ResumeAvailable ? largest_swap_part : ""
      # try to use label or udev id for device name... FATE #302219
      if resume != "" && !resume.nil?
        resume = ::Bootloader::UdevMapping.to_mountby_device(resume)
      end

      BootCommon.globals["append"]          ||= BootArch.DefaultKernelParams(resume)
      BootCommon.globals["append_failsafe"] ||= BootArch.FailsafeKernelParams
      # long name doesn't fit 800x600 GRUB screens, using short name by default
      # (bnc#873675)
      BootCommon.globals["distributor"]     ||= Product.short_name
      if !BootCommon.globals["distributor"] ||
          BootCommon.globals["distributor"].empty?
        BootCommon.globals["distributor"]     = Product.name
      end

      # Propose bootloader serial settings from kernel cmdline during install (bnc#862388)
      serial = BootCommon.GetSerialFromAppend

      if !serial.empty?
        BootCommon.globals["terminal"] ||= "serial"
        BootCommon.globals["serial"] ||= serial
      end

      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
    end

    # overwrite Save to allow generation of modification scripts
    def Save(clean, init, flush)
      case @password
      when nil
        GRUB2Pwd.new.disable
      when ""
        # do nothing
      else
        GRUB2Pwd.new.enable @password
      end

      BootCommon.Save(clean, init, flush)
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
