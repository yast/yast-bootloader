# frozen_string_literal: true

require "yast"
require "bootloader/bootloader_base"
require "bootloader/bls_sections"

Yast.import "Arch"
Yast.import "Report"
Yast.import "Stage"
Yast.import "Misc"

module Bootloader
  # Represents grub2 bls bootloader with efi target
  class Grub2Bls < Grub2Base
    include Yast::Logger
    include Yast::I18n

    attr_reader :sections

    CMDLINE = "/etc/kernel/cmdline"

    def initialize
      super
      textdomain "bootloader"

      @sections = ::Bootloader::BlsSections.new
      @is_read = false
      @is_proposed = false
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary(*)
      [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2 BLS"
        )
      ]
    end

    # @return bootloader name
    def name
      "grub2-bls"
    end

    # reads configuration from target disk
    def read
      read_menu_timeout
      @sections.read
      lines = ""
      filename = File.join(Yast::Installation.destdir, CMDLINE)
      if File.exist?(filename)
        File.open(filename).each do |line|
          lines = + line
        end
      end
      grub_default.kernel_params.replace(lines)
      log.info "kernel params: #{grub_default.kernel_params}"
      log.info "bls sections: #{@sections.all}"
      log.info "bls default:  #{@sections.default}"
      @is_read = true # flag that settings has been read
    end

    # @return true if configuration is already read
    def read?
      @is_read
    end

    # Proposes new configuration
    def propose
      log.info("Propose settings...")
      if grub_default.kernel_params.empty?
        kernel_line = Yast::BootArch.DefaultKernelParams(Yast::BootStorage.propose_resume)
        grub_default.kernel_params.replace(kernel_line)
      end
      grub_default.timeout = Yast::ProductFeatures.GetIntegerFeature("globals", "boot_timeout").to_i
      @is_proposed = true
    end

    # @return true if configuration is already proposed
    def proposed?
      @is_proposed
    end

    # writes configuration to target disk
    def write(*)
      install_bootloader if Yast::Stage.initial # while new installation only (currently)
      create_menu_entries
      install_bootloader
      @sections.write
      write_menu_timeout
      # writing kernel parameter to /etc/kernel/cmdline
      File.open(File.join(Yast::Installation.destdir, CMDLINE), "w+") do |fw|
        fw.puts(grub_default.kernel_params.serialize)
      end
    end

    # merges other bootloader configuration into this one.
    # It have to be same bootloader type.
    # rubocop:disable Metrics/AbcSize
    def merge(other)
      raise "Invalid merge argument #{other.name} for #{name}" if name != other.name

      log.info "merging: timeout: #{grub_default.timeout}=>#{other.grub_default.timeout}"
      log.info "         mitigations: #{cpu_mitigations.to_human_string}=>" \
               "#{other.cpu_mitigations.to_human_string}"
      log.info "         grub_default.kernel_params: #{grub_default.kernel_params.serialize}=>" \
               "#{other.grub_default.kernel_params.serialize}"

      merge_sections(other)
      merge_grub_default(other)

      log.info "merging result: timeout: #{grub_default.timeout}"
      log.info "                mitigations: #{cpu_mitigations.to_human_string}"
      log.info "                kernel_params: #{grub_default.kernel_params.serialize}"
    end
    # rubocop:enable Metrics/AbcSize

    # @return [Array<String>] packages required to configure given bootloader
    def packages
      res = super
      res << ("grub2-" + Yast::Arch.architecture + "-efi-bls")
      res << "sdbootutil"
      res << "grub2"
      res
    end

  private

    SDBOOTUTIL = "/usr/bin/sdbootutil"
    OS_RELEASE_PATH = "/etc/os-release"

    def grubenv_path
      str = Yast::Misc.CustomSysconfigRead("ID_LIKE", "openSUSE",
        OS_RELEASE_PATH)
      os = str.split.first
      File.join("/boot/efi/EFI/", os, "/grubenv")
    end

    # @return [String] return default boot as string or "" if not set
    # or something goes wrong
    def read_menu_timeout
      grub_default.timeout = Yast::Misc.CustomSysconfigRead("timeout", "",
        grubenv_path)
      log.info "Boot timeout: #{grub_default.timeout}"
    end

    def write_menu_timeout
      ret = Yast::Execute.on_target(SDBOOTUTIL,
        "set-timeout",
        grub_default.timeout,
        allowed_exitstatus: [0, 1])

      return unless ret != 0

      # fallback directly over grub2-editenv
      Yast::Execute.on_target("/usr/bin/grub2-editenv", grubenv_path,
        "set", "timeout=#{grub_default.timeout}")
    end

    def merge_sections(other)
      return if !other.sections.default || other.sections.default.empty?

      @sections.default = other.sections.default
    end

    def create_menu_entries
      Yast::Execute.on_target!(SDBOOTUTIL, "--verbose", "add-all-kernels")
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
        format(_(
                 "Cannot create grub2-bls menu entry:\n" \
                 "Command `%{command}`.\n" \
                 "Error output: %{stderr}"
               ), command: e.commands.inspect, stderr: e.stderr)
      )
    end

    def install_bootloader
      Yast::Execute.on_target!(SDBOOTUTIL, "--verbose",
        "install")
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
        format(_(
                 "Cannot install grub2-bls bootloader:\n" \
                 "Command `%{command}`.\n" \
                 "Error output: %{stderr}"
               ), command: e.commands.inspect, stderr: e.stderr)
      )
    end
  end
end
