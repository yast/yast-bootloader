# frozen_string_literal: true

require "fileutils"
require "yast"
require "bootloader/sysconfig"
require "bootloader/cpu_mitigations"
require "cfa/systemd_boot"

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

    # @!attribute menue_timeout
    #   @return [Integer] menue timeout
    attr_accessor :menue_timeout

    # @!attribute secure_boot
    #   @return [Boolean] current secure boot setting
    attr_accessor :secure_boot

    def initialize
      super

      textdomain "bootloader"
    end

    def merge(other)
      log.info "merging with system: timeout=#{other.menue_timeout} " \
               "secure_boot=#{other.secure_boot}"
      super
      self.menue_timeout = other.menue_timeout unless other.menue_timeout.nil?
      self.secure_boot = other.secure_boot unless other.secure_boot.nil?
    end

    def read
      super

      read_menue_timeout
      self.secure_boot = Systeminfo.secure_boot_active?
    end

    # Write bootloader settings to disk
    def write(etc_only: false)
      super
      log.info("Writing settings...")
      if Yast::Stage.initial # while new installation only (currently)
        install_bootloader
        create_menue_entries
      end
      write_menue_timeout

      true
    end

    def propose
      super
      log.info("Propose settings...")
      self.menue_timeout = Yast::ProductFeatures.GetIntegerFeature("globals", "boot_timeout").to_i
      self.secure_boot = Systeminfo.secure_boot_supported?
    end

    def status_string(status)
      if status
        _("enabled")
      else
        _("disabled")
      end
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

      #      res << "sdbootutil" << "systemd-boot"

      case Yast::Arch.architecture
      when "x86_64"
        res << "shim" if secure_boot
      else
        log.warn "Unknown architecture #{Yast::Arch.architecture} for EFI"
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

    SDBOOTUTIL = "/usr/bin/sdbootutil"

    def create_menue_entries
      cmdline_file = File.join(Yast::Installation.destdir, "/etc/kernel/cmdline")
      if Yast::Stage.initial
        # sdbootutil script needs the "root=<device>" entry in kernel parameters.
        # This will be written to /etc/kernel/cmdline which will be used in an
        # installed system by the administrator only. So we can use it because
        # the system will be installed new. This file will be deleted after
        # calling sdbootutil.
        File.open(cmdline_file, "w+") do |fw|
          fw.puts("root=#{Yast::BootStorage.root_partitions.first.name}")
        end
      end
      begin
        Yast::Execute.on_target!(SDBOOTUTIL, "--verbose", "add-all-kernels")
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot create systemd-boot menue entry:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
      end
      File.delete(cmdline_file) if Yast::Stage.initial # see above
    end

    def read_menue_timeout
      config = CFA::SystemdBoot.load
      self.menue_timeout = config.menue_timeout.to_i if config.menue_timeout
    end

    def write_menue_timeout
      config = CFA::SystemdBoot.load
      config.menue_timeout = menue_timeout.to_s
      config.save
    end

    def install_bootloader
      Yast::Execute.on_target!(SDBOOTUTIL, "--verbose",
        "install")
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
      format(_(
               "Cannot install systemd bootloader:\n" \
               "Command `%{command}`.\n" \
               "Error output: %{stderr}"
             ), command: e.commands.inspect, stderr: e.stderr)
    )
      nil
    end
  end
end
