# encoding: utf-8

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
      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "Region"
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

      devices = Storage.GetTargetMap
      mbr_disk = Storage.GetDisk(devices, BootStorage.mbr_disk)
      boot_device = Storage.GetPartition(devices, BootStorage.BootPartitionDevice)
      return true if mbr_disk["label"] != "gpt"
      return true if boot_device["used_fs"] != :btrfs
      return true if mbr_disk["partitions"].any? { |p| p["fsid"] == Partitions.fsid_bios_grub }

      Builtins.y2error("Used together boot from MBR, gpt, btrfs and without bios_grub partition.")
      # TRANSLATORS: description of technical problem. Do not translate technical terms unless native language have well known translation.
      add_new_problem(
        _(
          "Boot from MBR does not work together with btrfs filesystem and GPT disk label without bios_grub partition." \
          "To fix this issue, create bios_grub partition or use any ext filesystem for boot partition or do not install stage 1 to MBR."
        )
      )
      false
    end

    # Check if boot partition exist
    # check if not on raid0
    #
    # @return [Boolean] true on success

    def check_boot_device
      devices = Storage.GetTargetMap

      boot_device = BootStorage.BootPartitionDevice

      # check if boot device is on raid0
      (devices || {}).each do |_k, v|
        (v["partitions"] || []).each do |p|
          next if p["device"] != boot_device

          if p["raid_type"] != "raid1" && p["type"] == :sw_raid
            add_new_problem(
              Builtins.sformat(
                _(
                  "The boot device is on raid type: %1. System will not boot."
                ),
                p["raid_type"]
              )
            )
            log.error "The boot device: #{boot_device} is on raid type: #{p["raid_type"]}"
            return false
          # bnc#501043 added check for valid configuration
          elsif p["raid_type"] == "raid1" && p["type"] == :sw_raid &&
              (p["fstype"] || "") == "md raid" && stage1.boot_partition?
            add_new_problem(
              _(
                "The boot device is on software RAID1. Select other bootloader location, e.g. Master Boot Record"
              )
            )
            log.error "Booting from soft-raid: #{p} and bootloader setting are not valid: #{stage1.inspect}"
            return false
          else
            log.info "The boot device: #{boot_device} is on raid: #{p["raid_type"]}"
          end
          log.info "/boot filesystem is OK"
          return true
        end
      end

      true
    end

    # Check if EFI is needed
    def efi?
      cmd = "modprobe efivars 2>/dev/null"
      SCR.Execute(path(".target.bash_output"), cmd)
      FileUtils.Exists("/sys/firmware/efi/systab")
    end

    def check_zipl_part
      # if partitioning worked before upgrade, it will keep working (bnc#886604)
      return true if Mode.update

      boot_part = Storage.GetEntryForMountpoint("/boot/zipl")
      boot_part = Storage.GetEntryForMountpoint("/boot") if boot_part.empty?
      boot_part = Storage.GetEntryForMountpoint("/") if boot_part.empty?

      if [:ext2, :ext3, :ext4].include? boot_part["used_fs"]
        return true
      else
        add_new_problem(_("Missing ext partition for booting. Cannot install boot code."))
        return false
      end
    end

    def check_activate_partition
      # activate set or there is already activate flag
      return true if stage1.model.activate? || Yast::Storage.GetBootPartition(Yast::BootStorage.mbr_disk)

      add_new_problem(_("Activate flag is not set by installer. If it is not set at all, some BIOSes could refuse to boot."))
      false
    end

    def check_mbr
      return true if stage1.model.generic_mbr? || stage1.mbr?

      add_new_problem(_("The installer will not modify the MBR of the disk. Unless it already contains boot code, the BIOS won't be able to boot disk."))
      false
    end

    # GRUB2-related check
    def GRUB2

      ret = []
      ret << check_boot_device if Arch.x86_64
      # ensure that s390 have ext* partition for booting (bnc#873951)
      ret << check_zipl_part if Arch.s390
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
  end

  BootSupportCheck = BootSupportCheckClass.new
  BootSupportCheck.main
end
