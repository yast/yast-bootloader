# encoding: utf-8
require "yast"
require "bootloader/sections"
require "bootloader/grub2pwd"
require "bootloader/udev_mapping"
require "bootloader/serial_console"
require "config_files/grub2/default"
require "config_files/grub2/grub_cfg"
require "config_files/matcher"
require "config_files/placer"

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

module Bootloader
  # Common base for GRUB2 specialized classes
  class GRUB2Base < BootloaderBase
    include Yast::Logger
    include Yast::I18n

    # @!attribute password
    #    @return [::Bootloader::GRUB2Pwd] stored password configuration object
    attr_reader :password

    attr_reader :sections
    # @!attribute grub_default
    #    @return [CFA::Grub2::Default] grub2 configuration object
    attr_reader :grub_default

    attr_accessor :pmbr_action

    def initialize
      textdomain "bootloader"
      @password = ::Bootloader::GRUB2Pwd.new
      @grub_default = ::ConfigFiles::Grub2::Default.new
      @sections = []
      @pmbr_action = :nothing
    end

    # general functions

    # set pmbr flags on boot disks
    # TODO: move it to own place
    def pmbr_setup(*devices)
      return if @pmbr_action == :nothing

      action_parted = case @pmbr_action
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

    def read(reread: false)
      grub_default.load if !grub_default.loaded? || reread
      grub_cfg = CFA::Grub2::GrubConf.new
      grub_cfg.load
      @sections = ::Bootloader::Sections.new(grub_cfg)
    end

    def write
      super
      grub_default.save
      pmbr_setup
      @sections.write
      # TODO: call grub_install
      # TODO: call grub-mkconfig
    end

    def propose
      propose_os_probing
      propose_terminal
      propose_timeout

      if grub_default.kernel_params.empty?
        kernel_line = BootArch.DefaultKernelParams(propose_resume)
        grub_default.kernel_params.replace(kernel_line)
      end
      grub_default.gfxmode ||= "auto"
      grub_default.recovery_entry.disabled unless grub_default.recovery_entry.defined?
      grub_default.distributor ||= ""

      propose_serial

      nil
    end

    def save
      @password.write
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
