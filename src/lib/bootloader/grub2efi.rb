# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/grub_install"
require "bootloader/sysconfig"
require "y2storage"

Yast.import "Arch"
Yast.import "BootStorage"

module Bootloader
  # Represents grub2 bootloader with efi target
  class Grub2EFI < Grub2Base
    include Yast::Logger
    attr_accessor :secure_boot

    def initialize
      super

      textdomain "bootloader"

      @grub_install = GrubInstall.new(efi: true)
    end

    # Read settings from disk overwritting already set values
    def read
      @secure_boot = Sysconfig.from_system.secure_boot

      super
    end

    # Write bootloader settings to disk
    def write
      # super have to called as first as grub install require some config written in ancestor
      super

      if pmbr_action
        fs = filesystems
        efi_partition = fs.find { |f| f.mount_path == "/boot/efi" }
        efi_partition ||= fs.find { |f| f.mount_path == "/boot" }
        efi_partition ||= fs.find { |f| f.mount_path == "/" }

        raise "could not find boot partiton" unless efi_partition

        disks = Yast::BootStorage.stage1_disks_for(efi_partition)
        # set only gpt disks
        disks.select! { |disk| disk.gpt? }

        pmbr_setup(*disks.map(&:name))
      end

      @grub_install.execute(secure_boot: @secure_boot, trusted_boot: trusted_boot)

      true
    end

    def propose
      super

      # for UEFI always remove PMBR flag on disk (bnc#872054)
      self.pmbr_action = :remove

      # non-x86_64 systems don't support secure boot yet (bsc#978157) except arm (fate#326540)
      @secure_boot = (Yast::Arch.x86_64 || Yast::Arch.aarch64) ? true : false
      grub_default.generic_set("GRUB_USE_LINUXEFI", Yast::Arch.aarch64 ? "false" : "true")
    end

    def merge(other)
      super

      @secure_boot = other.secure_boot unless other.secure_boot.nil?
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary(*)
      [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2 EFI"
        ),
        Yast::Builtins.sformat(
          _("Enable Secure Boot: %1"),
          @secure_boot ? _("yes") : _("no")
        ),
        Yast::Builtins.sformat(
          _("Enable Trusted Boot: %1"),
          trusted_boot ? _("yes") : _("no")
        )
      ]
    end

    def name
      "grub2-efi"
    end

    def packages
      res = super

      case Yast::Arch.architecture
      when "i386"
        res << "grub2-i386-efi"
      when "x86_64"
        res << "grub2-x86_64-efi"
        res << "shim" << "mokutil" if @secure_boot
      when "arm"
        res << "grub2-arm-efi"
      when "aarch64"
        res << "grub2-arm64-efi"
      else
        log.warn "Unknown architecture #{Yast::Arch.architecture} for EFI"
      end

      res
    end

    # overwrite BootloaderBase version to save secure boot
    def write_sysconfig(prewrite: false)
      sysconfig = Bootloader::Sysconfig.new(bootloader: name,
        secure_boot: @secure_boot, trusted_boot: trusted_boot)
      prewrite ? sysconfig.pre_write : sysconfig.write
    end

  private

    # Filesystems in the staging (planned) devicegraph
    #
    # @return [Y2Storage::FilesystemsList]
    def filesystems
      staging = Y2Storage::StorageManager.instance.staging
      staging.filesystems
    end
  end
end
