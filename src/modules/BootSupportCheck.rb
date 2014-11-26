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
# $Id: BootCommon.ycp 49686 2008-08-05 10:04:46Z juhliarik $
#
require "yast"

module Yast
  class BootSupportCheckClass < Module
    def main
      textdomain "bootloader"

      Yast.import "Bootloader"
      Yast.import "Arch"
      Yast.import "Storage"
      Yast.import "Partitions"
      Yast.import "Region"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "FileUtils"
      Yast.import "Mode"

      # List of problems found during last check
      @detected_problems = []
    end

    # Add a new problem description to the list of found problems
    def AddNewProblem(description)
      @detected_problems = Builtins.add(@detected_problems, description)

      nil
    end

    # Formated string of detected problems
    # Always run SystemSupported before calling this function
    # @return [Boolean] a list of problems, empty if no was found
    def StringProblems
      ret = ""
      if Ops.greater_than(Builtins.size(@detected_problems), 0)
        Builtins.foreach(@detected_problems) do |s|
          ret = Ops.add(Ops.add(ret, s), "\n")
        end
      end

      ret
    end

    # Check that bootloader is known and supported
    def KnownLoader
      if !["grub2", "grub2-efi", "none"].include?(Bootloader.getLoaderType)
        Builtins.y2error("Unknown bootloader: %1", Bootloader.getLoaderType)
        AddNewProblem(
          Builtins.sformat(
            _("Unknown bootloader: %1"),
            Bootloader.getLoaderType
          )
        )
        return false
      end
      true
    end

    # Check that bootloader matches current hardware
    def CorrectLoaderType
      lt = Bootloader.getLoaderType
      return true if lt == "none"

      # grub2 is sooo cool...
      return true if lt == "grub2"

      if Arch.i386 || Arch.x86_64
        if efi?
          return true if lt == "grub2-efi"
        else
          return true if lt == "grub2"
        end
      end
      Builtins.y2error(
        "Unsupported combination of hardware platform %1 and bootloader %2",
        Arch.architecture,
        lt
      )
      AddNewProblem(
        Builtins.sformat(
          _("Unsupported combination of hardware platform %1 and bootloader %2"),
          Arch.architecture,
          lt
        )
      )
      false
    end

    #  * Checks for GPT partition table
    def GptPartitionTable
      ret = true
      tm = Storage.GetTargetMap
      devices = [BootStorage.BootPartitionDevice]
      # TODO: add more devices
      Builtins.foreach(devices) do |dev|
        p_dev = Storage.GetDiskPartition(dev)
        num = p_dev["nr"].to_i
        mbr_dev = Ops.get_string(p_dev, "disk", "")
        label = Ops.get_string(tm, [mbr_dev, "label"], "")
        Builtins.y2milestone("Label: %1", label)
        Builtins.y2milestone("Partition number: %1", num)
      end
      ret
    end

    # when grub2 is used and install stage1 to MBR, target /boot is btrfs, label is gpt-like
    # then there must be special partition to install core.img, otherwise grub2-install failed
    def check_gpt_reserved_partition
      return true if BootCommon.globals["boot_mbr"] != "true"

      devices = Storage.GetTargetMap
      mbr_disk = Storage.GetDisk(devices, BootCommon.FindMBRDisk)
      boot_device = Storage.GetPartition(devices, BootCommon.getBootPartition)
      return true if mbr_disk["label"] != "gpt"
      return true if boot_device["used_fs"] != :btrfs
      return true if mbr_disk["partitions"].any? { |p| p["fsid"] == Partitions.fsid_bios_grub }

      Builtins.y2error("Used together boot from MBR, gpt, btrfs and without bios_grub partition.")
      # TRANSLATORS: description of technical problem. Do not translate technical terms unless native language have well known translation.
      AddNewProblem(_(
          "Boot from MBR does not work together with btrfs filesystem and GPT disk label without bios_grub partition." \
          "To fix this issue, create bios_grub partition or use any ext filesystem for boot partition or do not install stage 1 to MBR."
      ))
      false
    end

    # Check if boot partition exist
    # check if not on raid0
    #
    # @return [Boolean] true on success

    def check_BootDevice
      result = true
      devices = Storage.GetTargetMap

      boot_device = BootCommon.getBootPartition

      found_boot = false
      # check if boot device is on raid0
      Builtins.foreach(devices) do |_k, v|
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          if Ops.get_string(p, "device", "") == boot_device
            if Ops.get_string(p, "raid_type", "") != "raid1" &&
                Ops.get(p, "type") == :sw_raid
              AddNewProblem(
                Builtins.sformat(
                  _(
                    "The boot device is on raid type: %1. System will not boot."
                  ),
                  Ops.get_string(p, "raid_type", "")
                )
              )
              Builtins.y2error(
                "The boot device: %1 is on raid type: %2",
                boot_device,
                Ops.get_string(p, "raid_type", "")
              )
              result = false
              raise Break
            else
              # bnc#501043 added check for valid configuration
              if Ops.get_string(p, "raid_type", "") == "raid1" &&
                  Ops.get(p, "type") == :sw_raid
                if Builtins.tolower(Ops.get_string(p, "fstype", "")) == "md raid" &&
                    Ops.get(BootCommon.globals, "boot_mbr", "false") != "true"
                  AddNewProblem(
                    _(
                      "The boot device is on software RAID1. Select other bootloader location, e.g. Master Boot Record"
                    )
                  )
                  Builtins.y2error(
                    "Booting from soft-raid: %1 and bootloader setting are not valid: %2",
                    p,
                    BootCommon.globals
                  )
                  result = false
                  raise Break
                else
                  found_boot = true
                  Builtins.y2milestone("Valid configuration for soft-raid")
                end
              else
                found_boot = true
                Builtins.y2milestone(
                  "The boot device: %1 is on raid: %2",
                  boot_device,
                  Ops.get_string(p, "raid_type", "")
                )
              end
            end
            found_boot = true
            Builtins.y2milestone("/boot filesystem is OK")
            raise Break
          end
        end
        raise Break if !result || found_boot
      end if boot_device != ""
      result
    end

    # Check if EFI is needed
    def efi?
      cmd = "modprobe efivars 2>/dev/null"
      SCR.Execute(path(".target.bash_output"), cmd)
      if FileUtils.Exists("/sys/firmware/efi/systab")
        return true
      else
        return false
      end
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
        AddNewProblem(_( "Missing ext partition for booting. Cannot install boot code."))
        return false
      end
    end

    # GRUB-related check
    def GRUB
      ret = GptPartitionTable()
      ret = check_BootDevice if ret
      ret
    end

    # GRUB2-related check
    def GRUB2
      ret = GRUB()
      # ensure that s390 have ext* partition for booting (bnc#873951)
      ret &&= check_zipl_part if Arch.s390
      ret &&= check_gpt_reserved_partition if Arch.x86_64

      ret
    end

    # GRUB2EFI-related check
    def GRUB2EFI
      true
    end

    # Check if the system configuraiton is supported
    # Also sets the founds problems into internal variable
    # Always run this function before calling DetectedProblems()
    # @return [Boolean] true if supported
    def SystemSupported
      @detected_problems = []

      # check if the bootloader is known and supported
      supported = KnownLoader()

      lt = Bootloader.getLoaderType
      return true if lt == "none"

      # detect correct bootloader type
      supported = CorrectLoaderType() && supported

      # check specifics for individual loaders
      if lt == "grub2"
        supported = GRUB2() && supported
      elsif lt == "grub2-efi"
        supported = GRUB2EFI() && supported
      end

      Builtins.y2milestone("Configuration supported: %1", supported)
      supported
    end

    def EndOfBootOrRootPartition
      part = Storage.GetEntryForMountpoint("/boot")
      part = Storage.GetEntryForMountpoint("/") if Builtins.isempty(part)

      device = Ops.get_string(part, "device", "")
      Builtins.y2milestone("device:%1", device)

      end_cyl = Region.End(Ops.get_list(part, "region", []))

      cyl_size = 82_252_800
      target_map = Storage.GetTargetMap
      Builtins.foreach(target_map) do |_dev, disk|
        partition = (disk["partitions"] || []).find do |p|
          p["device"] == device
        end

        cyl_size = disk["cyl_size"] || 82_252_800 if partition
      end

      ret = Ops.multiply(end_cyl, cyl_size)

      Builtins.y2milestone(
        "end_cyl:%1 cyl_size:%2 end:%3",
        end_cyl,
        cyl_size,
        ret
      )
      ret
    end

    publish :function => :StringProblems, :type => "string ()"
    publish :function => :SystemSupported, :type => "boolean ()"
    publish :function => :EndOfBootOrRootPartition, :type => "integer ()"
  end

  BootSupportCheck = BootSupportCheckClass.new
  BootSupportCheck.main
end
