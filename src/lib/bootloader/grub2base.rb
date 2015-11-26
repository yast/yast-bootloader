# encoding: utf-8
require "yast"
require "bootloader/grub2pwd"
require "bootloader/udev_mapping"
require "bootloader/serial_console"
require "config_files/grub2/default"
require "config_files/matcher"
require "config_files/placer"

module Yast
  # Common base for GRUB2 specialized classes
  class GRUB2Base < Module
    # @!attribute password
    #    @return [::Bootloader::GRUB2Pwd] stored password configuration object
    attr_reader :password
    attr_reader :grub_default

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

      @password = ::Bootloader::GRUB2Pwd.new
      @grub_default = ::ConfigFiles::Grub2::Default.new
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
        res = WFM.Execute(path(".local.bash_output"),
          "parted -s '#{dev}' disk_set pmbr_boot #{action_parted}")
        Builtins.y2milestone("parted disk_set pmbr: #{res}")
      end
    end

    # Propose global options of bootloader
    def StandardGlobals
      {
        "default"  => "0",
        "vgamode"  => "",
        "activate" => Arch.ppc ? "true" : "false"
      }
    end

    # Update read settings to new version of configuration files
    def Update
      Read(true, true)

      BootCommon.UpdateGlobals

      nil
    end

    # Reset bootloader settings
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

    def Read(reread, _avoid_reading_device_map)
      grub_default.load if !grub_default.loaded? || reread
    end

    def Write
      grub_default.save
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

      propose_os_probing
      propose_terminal
      propose_timeout

      BootCommon.globals = StandardGlobals().merge(BootCommon.globals || {})

      if grub_default.kernel_params.empty?
        kernel_line = BootArch.DefaultKernelParams(propose_resume)
        grub_default.kernel_params.replace(kernel_line)
      end
      grub_default.gfxmode ||= "auto"
      grub_default.recovery_entry.disabled unless grub_default.recovery_entry.defined?
      grub_default.distributor ||= ""

      propose_serial

      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
    end

    # overwrite Save to allow generation of modification scripts
    def Save(clean, init, flush)
      @password.write

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

    def enable_serial_console(console)
      console = SerialConsole.load_from_console_args(console)
      raise "Invalid console parameters" unless console

      grub_default.serial_console = console.console_args

      placer = ConfigFiles::ReplacePlacer.new(serial_console_matcher)
      kernel_params = grub_default.kernel_params
      kernel_params.add_parameter("console", console.kernel_args, placer)
    end

    def disable_serial_console
      grub_default.kernel_params.remove_parameter(serial_console_matcher)
    end

  private

    def serial_console_matcher
      ConfigFiles::Matcher.new(key: "console", value_matcher: /tty(S|AMA)/)
    end

    def propose_os_probing
      os_prober = grub_default.os_prober
      return if os_prober.defined?

      # s390 do not have os_prober, see bnc#868909#c2
      # ppc have slow os_prober, see boo#931653
      disable_os_prober = (Arch.s390 || Arch.ppc) ||
        ProductFeatures.GetBooleanFeature("globals", "disable_os_prober")
      if disable_os_prober
        os_prober.disable
      else
        os_prober.enable
      end
    end

    def propose_terminal
      return if grub_default.terminal

      grub_default.terminal = Arch.s390 ? :console : :gfxterm
    end

    def propose_timeout
      return if grub_default.timeout

      grub_default.timeout = 8
    end

    def propose_serial
      console = SerialConsole.load_from_kernel_args(grub_default.kernel_params)
      return unless console

      grub_default.serial_console = console.console_args
    end

    def propose_resume
      swap_parts = BootStorage.available_swap_partitions
      largest_swap_part = (swap_parts.max_by { |_part, size| size } || [""]).first

      resume = BootArch.ResumeAvailable ? largest_swap_part : ""
      # try to use label or udev id for device name... FATE #302219
      if resume != "" && !resume.nil?
        resume = ::Bootloader::UdevMapping.to_mountby_device(resume)
      end

      resume
    end
  end
end
