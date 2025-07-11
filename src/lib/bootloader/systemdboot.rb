# frozen_string_literal: true

require "fileutils"
require "yast"
require "bootloader/sysconfig"
require "bootloader/cpu_mitigations"
require "bootloader/bls"
require "bootloader/bls_sections"
require "cfa/grub2/default"

Yast.import "Report"
Yast.import "Arch"
Yast.import "ProductFeatures"
Yast.import "BootStorage"
Yast.import "Stage"

module Bootloader
  # Represents systemd bootloader with efi target
  class SystemdBoot < BootloaderBase
    include Yast::Logger
    include Yast::I18n

    CMDLINE = "/etc/kernel/cmdline"

    # @!attribute timeout
    #   @return [Integer] menu timeout
    attr_accessor :timeout
    alias_method :menu_timeout, :timeout # Agama compatible
    alias_method :menu_timeout=, :timeout= # Agama compatible

    # @!attribute secure_boot
    #   @return [Boolean] current secure boot setting
    attr_accessor :secure_boot

    attr_reader :sections

    # @!attribute pmbr_action
    #   @return [:remove, :add, :nothing]
    attr_accessor :pmbr_action

    def initialize
      super

      textdomain "bootloader"
      # For kernel parameters we are using the same data structure
      # like grub2 in order to be compatible with all calls.
      @kernel_container = ::CFA::Grub2::Default.new
      @explicit_cpu_mitigations = false
      @pmbr_action = :nothing
      @sections = ::Bootloader::BlsSections.new
    end

    def kernel_params
      @kernel_container.kernel_params
    end

    # rubocop:disable Metrics/AbcSize
    def merge(other)
      log.info "merging: timeout: #{timeout}=>#{other.timeout}"
      log.info "         secure_boot: #{secure_boot}=>#{other.secure_boot}"
      log.info "         mitigations: #{cpu_mitigations.to_human_string}=>" \
               "#{other.cpu_mitigations.to_human_string}"
      log.info "         pmbr_action: #{pmbr_action}=>#{other.pmbr_action}"
      log.info "         kernel_params: #{kernel_params.serialize}=>" \
               "#{other.kernel_params.serialize}"
      log.info "         default menu: #{@sections.default}=>" \
               "#{other.sections.default}"
      super
      self.timeout = other.timeout unless other.timeout.nil?
      self.secure_boot = other.secure_boot unless other.secure_boot.nil?
      self.pmbr_action = other.pmbr_action if other.pmbr_action

      kernel_serialize = kernel_params.serialize
      # handle specially noresume as it should lead to remove all other resume
      kernel_serialize.gsub!(/resume=\S+/, "") if other.kernel_params.parameter("noresume")

      # prevent double cpu_mitigations params
      kernel_serialize.gsub!(/mitigations=\S+/, "") if other.kernel_params.parameter("mitigations")

      new_kernel_params = "#{kernel_serialize} #{other.kernel_params.serialize}"
      # deduplicate identicatel parameter. Keep always the last one ( so reverse is needed ).
      new_params = new_kernel_params.split.reverse.uniq.reverse.join(" ")

      @kernel_container.kernel_params.replace(new_params)

      # explicitly set mitigations means overwrite of our
      self.cpu_mitigations = other.cpu_mitigations if other.explicit_cpu_mitigations

      @sections.default = other.sections.default if other.sections.default

      log.info "merging result: timeout: #{timeout}"
      log.info "                secure_boot: #{secure_boot}"
      log.info "                mitigations: #{cpu_mitigations.to_human_string}"
      log.info "                kernel_params: #{kernel_params.serialize}"
      log.info "                pmbr_action: #{pmbr_action}"
      log.info "                default menu: #{@sections.default}"
    end
    # rubocop:enable Metrics/AbcSize

    def cpu_mitigations
      CpuMitigations.from_kernel_params(kernel_params)
    end

    def explicit_cpu_mitigations
      @explicit_cpu_mitigations ? cpu_mitigations : nil
    end

    def cpu_mitigations=(value)
      log.info "set mitigations to #{value.to_human_string}"
      @explicit_cpu_mitigations = true
      value.modify_kernel_params(kernel_params)
    end

    def read
      super

      @sections.read
      self.timeout = Bls.menu_timeout
      self.secure_boot = Systeminfo.secure_boot_active?

      lines = ""
      filename = File.join(Yast::Installation.destdir, CMDLINE)
      if File.exist?(filename)
        File.open(filename).each do |line|
          lines = + line
        end
      end
      @kernel_container.kernel_params.replace(lines)
    end

    # Write bootloader settings to disk
    def write(etc_only: false)
      super
      log.info("Writing settings...")
      write_kernel_parameter
      if Yast::Stage.initial # while new installation only (currently)
        Bls.install_bootloader
        Bls.set_authentication
      end

      Bls.create_menu_entries
      Bls.write_menu_timeout(timeout)
      @sections.write
      Pmbr.write_efi(pmbr_action)

      true
    end

    def propose
      super
      log.info("Propose settings...")
      if @kernel_container.kernel_params.empty?
        kernel_line = Yast::BootArch.DefaultKernelParams(Yast::BootStorage.propose_resume)
        @kernel_container.kernel_params.replace(kernel_line)
      end
      self.timeout = Yast::ProductFeatures.GetIntegerFeature("globals", "boot_timeout").to_i
      self.secure_boot = Systeminfo.secure_boot_supported?
      # for UEFI always remove PMBR flag on disk (bnc#872054)
      self.pmbr_action = :remove
    end

    # Secure boot setting shown in summary screen.
    # sdbootutil intialize secure boot if shim has been installed.
    #
    # @return [String]
    def secure_boot_summary
      link = if secure_boot
        "<a href=\"disable_secure_boot\">(#{_("disable")})</a>"
      else
        "<a href=\"enable_secure_boot\">(#{_("enable")})</a>"
      end

      "#{_("Secure Boot:")} #{status_string(secure_boot)} #{link}"
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary(*)
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "Systemd Boot"
        )
      ]
      result << secure_boot_summary if Systeminfo.secure_boot_available?(name)
      result
    end

    def name
      "systemd-boot"
    end

    def packages
      res = super
      res << "sdbootutil" << "systemd-boot"

      if ["x86_64", "aarch64"].include?(Yast::Arch.architecture)
        res << "shim"
      else
        log.warn "Unknown architecture #{Yast::Arch.architecture} for systemd-boot"
      end

      res
    end

    def delete
      log.warn("is currently not supported")
    end

    # overwrite BootloaderBase version to save secure boot
    def write_sysconfig(prewrite: false)
      sysconfig = Bootloader::Sysconfig.new(bootloader: name,
        secure_boot: secure_boot, trusted_boot: false,
        update_nvram: false)
      prewrite ? sysconfig.pre_write : sysconfig.write
    end

  private

    def write_kernel_parameter
      # writing kernel parameter to /etc/kernel/cmdline
      File.open(File.join(Yast::Installation.destdir, CMDLINE), "w+") do |fw|
        if Yast::Stage.initial # while new installation only
          fw.puts("root=#{Yast::BootStorage.root_partitions.first.name} #{kernel_params.serialize}")
        else # root entry is already available
          fw.puts(kernel_params.serialize)
        end
      end
    end
  end
end
