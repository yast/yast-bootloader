# frozen_string_literal: true

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

    def initialize
      super

      textdomain "bootloader"

      @grub_install = GrubInstall.new(efi: true)
    end

    # Read settings from disk overwritting already set values
    def read
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

      @grub_install.execute(secure_boot: secure_boot, trusted_boot: trusted_boot,
                            update_nvram: update_nvram)

      true
    end

    def propose
      super

      # for UEFI always remove PMBR flag on disk (bnc#872054)
      self.pmbr_action = :remove

      grub_default.generic_set("GRUB_USE_LINUXEFI", Yast::Arch.aarch64 ? "false" : "true")
    end

    def merge(other)
      super
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary(*)
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2 EFI"
        )
      ]

      result << secure_boot_summary if Systeminfo.secure_boot_available?(name)
      result << trusted_boot_summary if Systeminfo.trusted_boot_available?(name)
      result << update_nvram_summary if Systeminfo.nvram_available?(name)

      result
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
        res << "shim" << "mokutil" if secure_boot
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
        secure_boot: secure_boot, trusted_boot: trusted_boot,
        update_nvram: update_nvram)
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
