# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/grub_install"
require "bootloader/sysconfig"
require "bootloader/stage1_device"
require "y2storage"

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

    # Read settings from disk overwritting already set values
    def read
      @secure_boot = Sysconfig.from_system.secure_boot

      super
    end

    # Write bootloader settings to disk
    def write
      # super have to called as first as grub install require some config written in ancestor
      super

      if pmbr_action && Yast::BootStorage.gpt_boot_disk?
        efi_partition = filesystems.select { |f| f.mountpoint == "/boot/efi" }.partitions.first
        efi_partition ||= filesystems.select { |f| f.mountpoint == "/boot" }.partitions.first
        efi_partition ||= filesystems.select { |f| f.mountpoint == "/" }.partitions.first

        raise "could not find boot partiton" unless efi_partition

        efi_disk = efi_partition.disk

# storage-ng
# rubocop:disable Style/BlockComments
=begin
        # get underlaying disk as it have to be set there and not on virtual one (bnc#981977)
        device = ::Bootloader::Stage1Device.new(efi_disk)
=end

        pmbr_setup(efi_disk.name)
      end

      @grub_install.execute(secure_boot: @secure_boot, trusted_boot: trusted_boot)

      true
    end

    def propose
      super

      # for UEFI always remove PMBR flag on disk (bnc#872054)
      self.pmbr_action = :remove

      # non-x86_64 systems don't support secure boot yet (bsc#978157)
      @secure_boot = Yast::Arch.x86_64 ? true : false
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
      staging = Y2Storage::StorageManager.instance.y2storage_staging
      staging.filesystems
    end
  end
end
