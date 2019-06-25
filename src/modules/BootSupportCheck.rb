# frozen_string_literal: true

# File:
#      modules/BootSupportCheck.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Check whether the current system setup is a supported configuration
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
require "yast"

require "bootloader/bootloader_factory"

module Yast
  class BootSupportCheckClass < Module
    include Yast::Logger

    def main
      textdomain "bootloader"

      Yast.import "Bootloader"
      Yast.import "Arch"
      Yast.import "BootStorage"
      Yast.import "FileUtils"
      Yast.import "Mode"

      # List of problems found during last check
      @detected_problems = []
    end

    # Check if the system configuraiton is supported
    # Also sets the founds problems into internal variable
    # Always run this function before calling DetectedProblems()
    # @return [Boolean] true if supported
    def SystemSupported
      @detected_problems = []

      lt = ::Bootloader::BootloaderFactory.current.name
      # detect correct bootloader type
      supported = correct_loader_type(lt)

      # check specifics for individual loaders
      case lt
      when "grub2"
        supported = GRUB2() && supported
      when "grub2-efi"
        supported = GRUB2EFI() && supported
      end

      log.info "Configuration supported: #{supported}"

      supported
    end

    # Formated string of detected problems
    # Always run SystemSupported before calling this function
    # @return [Boolean] a list of problems, empty if no was found
    def StringProblems
      @detected_problems.join("\n")
    end

    publish :function => :StringProblems, :type => "string ()"
    publish :function => :SystemSupported, :type => "boolean ()"

  private

    # Add a new problem description to the list of found problems
    def add_new_problem(description)
      @detected_problems << description
    end

    # Check that bootloader matches current hardware
    def correct_loader_type(lt)
      return true if lt == "none"

      # grub2 is sooo cool...
      return true if lt == "grub2" && !Arch.aarch64

      return true if (Arch.i386 || Arch.x86_64) && lt == "grub2-efi" && efi?

      return true if lt == "grub2-efi" && Arch.aarch64

      log.error "Unsupported combination of hardware platform #{Arch.architecture} and bootloader #{lt}"
      add_new_problem(
        Builtins.sformat(
          _("Unsupported combination of hardware platform %1 and bootloader %2"),
          Arch.architecture,
          lt
        )
      )
      false
    end

    # when grub2 is used and install stage1 to MBR, target /boot is btrfs, label is gpt-like
    # then there must be special partition to install core.img, otherwise grub2-install failed
    def check_gpt_reserved_partition
      return true unless stage1.mbr?

      boot_fs = BootStorage.boot_filesystem
      gpt_disks = BootStorage.stage1_disks_for(boot_fs).select(&:gpt?)
      return true if gpt_disks.empty?
      return true if boot_fs.type != ::Y2Storage::Filesystems::Type::BTRFS
      # more relax check, at least one disk is enough. Let propose more advanced stuff like boot
      # duplicite md raid1 with bios_boot on all disks to storage and user. Check there only when
      # we are sure it is problem (bsc#1125792)
      return true if gpt_disks.any? { |disk| disk.partitions.any? { |p| p.id.is?(:bios_boot) } }

      Builtins.y2error("Used together boot from MBR, gpt, btrfs and without bios_grub partition.")
      # TRANSLATORS: description of technical problem. Do not translate technical terms unless native language have well known translation.
      add_new_problem(
        _(
          "Boot from MBR does not work together with Btrfs filesystem and GPT disk label\n" \
          "without bios_grub partition.\n\n" \
          "To fix this issue,\n\n" \
          " - create a bios_grub partition, or\n" \
          " - use any Ext filesystem for boot partition, or\n" \
          " - do not install stage 1 to MBR."
        )
      )
      false
    end

    # Check if boot partition exist
    # check if not on raid0
    #
    # @return [Boolean] true on success

    # Check if EFI is needed
    def efi?
      cmd = "/usr/sbin/modprobe efivars 2>/dev/null"
      SCR.Execute(path(".target.bash_output"), cmd)
      FileUtils.Exists("/sys/firmware/efi/systab")
    end

    def check_activate_partition
      # activate set
      return true if stage1.activate?

      # there is already activate flag
      disks = Yast::BootStorage.boot_disks

      # do not activate for ppc and GPT see bsc#983194
      return true if Arch.ppc64 && disks.all?(&:gpt?)

      all_activate = disks.all? do |disk|
        if disk.partition_table
          legacy_boot = disk.partition_table.partition_legacy_boot_flag_supported?

          disk.partitions.any? { |p| legacy_boot ? p.legacy_boot? : p.boot? }
        else
          false
        end
      end

      return true if all_activate

      add_new_problem(_("Activate flag is not set by installer. If it is not set at all, some BIOSes could refuse to boot."))
      false
    end

    def check_mbr
      return true if stage1.generic_mbr? || stage1.mbr?

      add_new_problem(_("The installer will not modify the MBR of the disk. Unless it already contains boot code, the BIOS won't be able to boot from this disk."))
      false
    end

    # GRUB2-related check
    def GRUB2
      ret = []
      ret << check_gpt_reserved_partition if Arch.x86_64
      ret << check_activate_partition if Arch.x86_64 || Arch.ppc64
      ret << check_mbr if Arch.x86_64

      ret.all?
    end

    # GRUB2EFI-related check
    def GRUB2EFI
      true
    end

    def stage1
      ::Bootloader::BootloaderFactory.current.stage1
    end

    def staging
      Y2Storage::StorageManager.instance.staging
    end
  end

  BootSupportCheck = BootSupportCheckClass.new
  BootSupportCheck.main
end
