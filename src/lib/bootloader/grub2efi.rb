# encoding: utf-8

require "yast"
require "bootloader/grub2base"
require "bootloader/grub_install"
require "bootloader/sysconfig"

module Bootloader
  # Represents grub2 bootloader with efi target
  class Grub2EFI < GRUB2Base
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
    # @return [Boolean] true on success
    def write
      # TODO: move to own class
      # something with PMBR needed
      if BootCommon.pmbr_action
        efi_disk = Storage.GetEntryForMountpoint("/boot/efi")["device"]
        efi_disk ||= Storage.GetEntryForMountpoint("/boot")["device"]
        efi_disk ||= Storage.GetEntryForMountpoint("/")["device"]

        pmbr_setup(BootCommon.pmbr_action, efi_disk)
      end

      super

      @grub_install.execute(secure_boot: @secure_boot)

      ret
    end

    def propose
      super

      # for UEFI always set PMBR flag on disk (bnc#872054)
      BootCommon.pmbr_action = :add if !BootCommon.was_proposed || Mode.autoinst || Mode.autoupgrade

      @secure_boot = true
    end

    # Display bootloader summary
    # @return a list of summary lines

    def summary
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2 EFI"
        )
      ]

      result + Yast::Builtins.sformat(
        _("Enable Secure Boot: %1"),
        @secure_boot ? _("yes") : _("no")
      )
    end

    def name
      "grub2-efi"
    end

  private

    # overwrite BootloaderBase version to save secure boot
    def write_sysconfig
      sysconfig = Bootloader::Sysconfig.new(bootloader: name, secure_boot: @secure_boot)
      sysconfig.write
    end
  end
end
