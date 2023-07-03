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

    def cpu_mitigations
      log.info "cpu_mitigations not supported in systemd-boot"
      return ""
    end

    def read
      super

      read_menue_timeout
      self.secure_boot = Systeminfo.secure_boot_active?
    end

    # Write bootloader settings to disk
    def write(etc_only: false)
      # super have to called as first as grub install require some config written in ancestor
      super
      log.info("Writing settings...")

      install_bootloader
      create_menue_entries
#      write_menue_timeout

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

      case Yast::Arch.architecture
      when "x86_64"
        res << "shim" << "mokutil" if secure_boot
      else
        log.warn "Unknown architecture #{Yast::Arch.architecture} for EFI"
      end

      res
    end

    def delete
      delete_bootloader
    end

    # overwrite BootloaderBase version to save secure boot
    def write_sysconfig(prewrite: false)
      sysconfig = Bootloader::Sysconfig.new(bootloader: name,
        secure_boot: secure_boot, trusted_boot: false,
        update_nvram: false)
      prewrite ? sysconfig.pre_write : sysconfig.write
    end

  private

    LS = "/bin/ls"
    KERNELINSTALL = "/usr/bin/kernel-install"
    BOOTCTL = "/bin/bootctl"
    SDBOOTUTIL = "/usr/bin/sdbootutil"
    CAT = "/bin/cat"
    MOKUTIL = "/bin/mokutil"

    def create_menue_entries
      begin
        Yast::Execute.on_target!(SDBOOTUTIL, "add-all-kernels")
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot create systemd-boot menue entry:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
      end
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

    def bootloader_is_installed
      Yast::Execute.on_target(BOOTCTL, "is-installed", allowed_exitstatus: 1) == 0
    end

    def remove_secure_boot_settings
      del_files = ["/boot/efi/EFI/systemd/grub.efi",
                   "/boot/efi/EFI/systemd/systemd-bootx64.efi",
                   "/boot/efi/EFI/systemd/MokManager.efi"]
      del_files.each do |f|
        filename = File.join(Yast::Installation.destdir, f)
        File.delete(filename) if File.exist?(filename)
      end
    end

    def secure_boot_available
      ret = false
      begin
        ret = Yast::Execute.on_target(MOKUTIL, "--sb-state", allowed_exitstatus: 1) == 0
      rescue Cheetah::ExecutionFailed => e
        log.info("Command `#{e.commands.inspect}`.\n" \
                 "Error output: #{e.stderr}")
      end
      ret
    end

    def delete_bootloader
      return unless bootloader_is_installed

      log.info("Removing already installed systemd bootmanager.")
      begin
        Yast::Execute.on_target!(BOOTCTL, "remove")
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
        format(_(
               "Cannot remove systemd bootloader:\n" \
               "Command `%{command}`.\n" \
               "Error output: %{stderr}"
             ), command: e.commands.inspect, stderr: e.stderr)
      )
        return
      end
      remove_secure_boot_settings
    end

    def set_secure_boot
      # If secure boot is enabled, shim needs to be installed.
      # As shim only reads grub.efi, systemd-boot needs to be renamed to pretend it's grub:
      log.info("Enabling secure boot options")
      src = File.join(Yast::Installation.destdir, "/boot/efi/EFI/systemd/systemd-bootx64.efi")
      dest = File.join(Yast::Installation.destdir, "/boot/efi/EFI/systemd/grub.efi")
      FileUtils.mv(src, dest) if File.exist?(src)
      src = File.join(Yast::Installation.destdir, "/usr/share/efi/", Yast::Arch.architecture,
        "/shim.efi")
      dest = File.join(Yast::Installation.destdir, "/boot/efi/EFI/systemd/systemd-bootx64.efi")
      FileUtils.cp(src, dest) if File.exist?(src)
      src = File.join(Yast::Installation.destdir, "/usr/share/efi/", Yast::Arch.architecture,
        "/MokManager.efi")
      dest = File.join(Yast::Installation.destdir, "/boot/efi/EFI/systemd/MokManager.efi")
      FileUtils.cp(src, dest) if File.exist?(src)
    end

    def install_bootloader
      begin
#        delete_bootloader # if bootloader is already installed
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
        return
      end
return      
      return unless secure_boot

      if secure_boot_available
        set_secure_boot
      else
        Yast::Report.Error(_("Cannot activate secure boot because it is not available " \
                             "on your system."))
      end
    end
  end
end
