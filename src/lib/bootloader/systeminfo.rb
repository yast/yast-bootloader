# frozen_string_literal: true

require "yast"
require "bootloader/bootloader_factory"
require "bootloader/sysconfig"

Yast.import "Arch"

module Bootloader
  # provide system and architecture dependent information
  class Systeminfo
    include Yast::Logger

    class << self
      # true if secure boot is currently active
      def secure_boot_active?
        (efi_supported? && Sysconfig.from_system.secure_boot) || s390_secure_boot_active?
      end

      # true if secure boot is (in principle) supported on this system
      def secure_boot_supported?
        efi_supported? || s390_secure_boot_supported?
      end

      # true if secure boot setting is available for current bootloader
      def secure_boot_available?(bootloader_name)
        efi_used?(bootloader_name) || s390_secure_boot_supported?
      end

      # true if trusted boot is currently active
      def trusted_boot_active?
        # FIXME: this should probably be a real check as in Grub2Widget#validate
        #   and then Grub2Widget#validate should use Systeminfo.trusted_boot_active?
        Sysconfig.from_system.trusted_boot
      end

      # true if trusted boot setting is available for current bootloader
      def trusted_boot_available?(bootloader_name)
        # for details about grub2 efi trusted boot support see FATE#315831
        (
          bootloader_name == "grub2" &&
          (Yast::Arch.x86_64 || Yast::Arch.i386)
        ) || (
          bootloader_name == "grub2-efi" &&
          File.exist?("/dev/tpm0")
        )
      end

      # true if UEFI will be used for booting
      def efi_used?(bootloader_name)
        bootloader_name == "grub2-efi"
      end

      # true if system can (in principle) boot via UEFI
      def efi_supported?
        Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.aarch64
      end

      # true if shim has to be used
      def shim_needed?(bootloader_name, secure_boot)
        (Yast::Arch.x86_64 || Yast::Arch.i386) && secure_boot && efi_used?(bootloader_name)
      end

      # true if s390 machine has secure boot support
      def s390_secure_boot_supported?
        Yast::Arch.s390
      end

      # true if 390x machine has secure boot enabled
      def s390_secure_boot_active?
        false
      end
    end
  end
end
