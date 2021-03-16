# frozen_string_literal: true

require "yast"
require "bootloader/bootloader_factory"
require "bootloader/sysconfig"
require "yast2/execute"

Yast.import "Arch"

module Bootloader
  # Provide system and architecture dependent information
  class Systeminfo
    class << self
      # Check current secure boot state.
      #
      # This prefers the 'real' state over the config file setting, if possible.
      #
      # @return [Boolean] true if secure boot is currently active
      def secure_boot_active?
        (efi_supported? || s390_secure_boot_supported?) && Sysconfig.from_system.secure_boot
      end

      # Check if secure boot is in principle supported.
      #
      # @return [Boolean] true if secure boot is (in principle) supported on this system
      # def secure_boot_supported?
      #  efi_supported? || s390_secure_boot_supported?
      # end

      # Check if secure boot is configurable with a bootloader.
      #
      # @param bootloader_name [String] bootloader name
      # @return [Boolean] true if secure boot setting is available with this bootloader
      def secure_boot_available?(bootloader_name)
        efi_used?(bootloader_name) || s390_secure_boot_available?
      end

      # Check current trusted boot state.
      #
      # ATM this just returns the config file setting.
      #
      # @return [Boolean] true if trusted boot is currently active
      def trusted_boot_active?
        # FIXME: this should probably be a real check as in Grub2Widget#validate
        #   and then Grub2Widget#validate could use Systeminfo.trusted_boot_active?
        Sysconfig.from_system.trusted_boot
      end

      # Check if trusted boot is configurable with a bootloader.
      #
      # param bootloader_name [String] bootloader name
      # @return [Boolean] true if trusted boot setting is available with this bootloader
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

      # Check if UEFI will be used.
      #
      # param bootloader_name [String] bootloader name
      # @return [Boolean] true if UEFI will be used for booting with this bootloader
      def efi_used?(bootloader_name)
        bootloader_name == "grub2-efi"
      end

      # Check if UEFI is available on this system.
      #
      # It need not currently be used. It should just be possible to put the
      # system into UEFI mode.
      #
      # @return [Boolean] true if system can (in principle) boot via UEFI
      def efi_supported?
        Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.aarch64
      end

      # Check if shim-install should be used instead of grub2-install.
      #
      # param bootloader_name [String] bootloader name
      # param secure_boot [Boolean] secure boot setting
      # @return [Boolean] true if shim has to be used
      def shim_needed?(bootloader_name, secure_boot)
        (Yast::Arch.x86_64 || Yast::Arch.i386) && secure_boot && efi_used?(bootloader_name)
      end

      # Check if secure boot is (in principle) available on an s390 machine.
      #
      # @return [Boolean] true if this is an s390 machine and it has secure boot support
      def s390_secure_boot_available?
        # see jsc#SLE-9425
        File.read("/sys/firmware/ipl/has_secure", 1) == "1"
      rescue StandardError
        false
      end

      # Check if secure boot is supported with the current setup.
      #
      # The catch here is that secure boot works only with SCSI disks.
      #
      # @return [Boolean] true if this is an s390 machine and secure boot is
      #   supported with the current setup
      def s390_secure_boot_supported?
        s390_secure_boot_available? && scsi?(zipl_device)
      end

      # Check if secure boot is currently active on an s390 machine.
      #
      # The 'real' state, not any config file setting.
      #
      # @return [Boolean] true if 390x machine has secure boot enabled
      def s390_secure_boot_active?
        # see jsc#SLE-9425
        File.read("/sys/firmware/ipl/secure", 1) == "1"
      rescue StandardError
        false
      end

      # The partition where zipl is installed.
      #
      # @return [Y2Storage::Partition, NilClass] zipl partition
      def zipl_device
        staging = Y2Storage::StorageManager.instance.staging
        mountpoint =
          Y2Storage::MountPoint.find_by_path(staging, "/boot/zipl").first ||
          Y2Storage::MountPoint.find_by_path(staging, "/boot").first ||
          Y2Storage::MountPoint.find_by_path(staging, "/").first
        mountpoint.filesystem.blk_devices.first
      rescue StandardError
        nil
      end

      # Check if device is a SCSI device.
      #
      # param device [Y2Storage::Partition, NilClass] partition device (or nil)
      #
      # @return [Boolean] true if device is a SCSI device
      def scsi?(device)
        # checking if device name starts with 'sd' is not enough: it could
        # be a device mapper target (e.g. multipath)
        # see bsc#1171821
        device.name.start_with?("/dev/sd") || device.udev_ids.any?(/^scsi-/)
      rescue StandardError
        false
      end

      # Checks if efivars exists and can be written
      # @see https://bugzilla.suse.com/show_bug.cgi?id=1174111#c37
      #
      # @return [Boolean] true if efivars are writable
      def writable_efivars?
        # quick check if there are no efivars at all
        return false if Dir.glob("/sys/firmware/efi/efivars/*").empty?

        # check if efivars are ro
        mounts = Yast::Execute.locally!("/usr/bin/mount", stdout: :capture)
        # target line looks like:
        # efivarfs on /sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
        efivars = mounts.lines.grep(/type\s+efivarfs/)
        efivars = efivars.first
        return false unless efivars

        efivars.match?(/[\(,]rw[,\)]/)
      rescue Cheetah::ExecutionFailed
        false
      end
    end
  end
end
