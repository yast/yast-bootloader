# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/grub_install"
require "bootloader/sysconfig"

Yast.import "Arch"

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

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # internal data
    # @return [Boolean] true on success
    def read(reread: false)
      @secure_boot = Sysconfig.from_system.secure_boot if reread || @secure_boot.nil?

      super
    end

    # Write bootloader settings to disk
    def write
      if pmbr_action
        efi_partition = Yast::Storage.GetEntryForMountpoint("/boot/efi")["device"]
        efi_partition ||= Yast::Storage.GetEntryForMountpoint("/boot")["device"]
        efi_partition ||= Yast::Storage.GetEntryForMountpoint("/")["device"]
        efi_disk = Yast::Storage.GetDiskPartition(efi_partition)["disk"]

        pmbr_setup(efi_disk)
      end

      super

      @grub_install.execute(secure_boot: @secure_boot)

      true
    end

    def propose
      super

      # for UEFI always remove PMBR flag on disk (bnc#872054)
      self.pmbr_action = :remove

      @secure_boot = true
    end

    def merge(other)
      super

      @secure_boot = other.secure_boot unless other.secure_boot.nil?
    end

    # Display bootloader summary
    # @return a list of summary lines

    def summary
      [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2 EFI"
        ),
        Yast::Builtins.sformat(
          _("Enable Secure Boot: %1"),
          @secure_boot ? _("yes") : _("no")
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
      when "aarch64"
        res << "grub2-arm64-efi"
      else
        log.warn "Unknown architecture #{Yast::Arch.architecture} for EFI"
      end

      res
    end

    # overwrite BootloaderBase version to save secure boot
    def write_sysconfig(prewrite: false)
      sysconfig = Bootloader::Sysconfig.new(bootloader: name, secure_boot: @secure_boot)
      prewrite ? sysconfig.pre_write : sysconfig.write
    end
  end
end
