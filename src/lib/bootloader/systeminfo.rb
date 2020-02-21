# frozen_string_literal: true

require "yast"
require "bootloader/bootloader_factory"

Yast.import "Arch"

module Bootloader
  # provide system and architecture dependent information
  class Systeminfo
    include Yast::Logger

    class << self
      # true if secure boot is currently active
      def secure_boot_active?
        efi_supported? || s390_secure_boot_active?
      end

      # true if boot config uses secure boot
      def secure_boot_used?
        ::Bootloader::BootloaderFactory.current.secure_boot
      end

      # true if secure boot is (in principle) supported
      def secure_boot_supported?
        efi_supported? || s390_secure_boot_supported?
      end

      # true if secure boot setting is available for current boot config
      def secure_boot_available?
        efi_used? || s390_secure_boot_supported?
      end

      # true if trusted boot setting is available for current boot config
      def trusted_boot_available?
        # for details about grub2 efi trusted boot support see FATE#315831
        (
          ::Bootloader::BootloaderFactory.current.name == "grub2" &&
          (Yast::Arch.x86_64 || Yast::Arch.i386)
        ) || (
          ::Bootloader::BootloaderFactory.current.name == "grub2-efi" &&
          File.exist?("/dev/tpm0")
        )
      end

      # true if UEFI will be used for booting
      def efi_used?
        ::Bootloader::BootloaderFactory.current.name == "grub2-efi"
      end

      # true if system can (in principle) boot via UEFI
      def efi_supported?
        Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.aarch64
      end

      # true if shim has to be used
      def shim_needed?
        (Yast::Arch.x86_64 || Yast::Arch.i386) && secure_boot_used? && efi_used?
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
