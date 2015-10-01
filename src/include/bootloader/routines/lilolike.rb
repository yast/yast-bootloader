# encoding: utf-8

# File:
#      modules/BootCommon.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Data to be shared between common and bootloader-specific parts of
#      bootloader configurator/installator, generic versions of bootloader
#      specific functions
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
require "bootloader/stage1"

module Yast
  module BootloaderRoutinesLilolikeInclude
    def initialize_bootloader_routines_lilolike(include_target)
      textdomain "bootloader"

      Yast.import "BootStorage"
      Yast.import "Storage"

      Yast.include include_target, "bootloader/routines/i386.rb"
    end

    # FindMbrDisk()
    # try to find the system's mbr device
    # @return [String]   mbr device
    def FindMBRDisk
      # check the disks order, first has MBR
      order = BootStorage.DisksOrder
      if Ops.greater_than(Builtins.size(order), 0)
        ret = Ops.get(order, 0, "")
        Builtins.y2milestone("First disk in the order: %1, using for MBR", ret)
        return ret
      end

      # OK, order empty, use the disk with boot partition
      mp = Storage.GetMountPoints
      boot_disk = Ops.get_string(
        mp,
        ["/boot", 2],
        Ops.get_string(mp, ["/", 2], "")
      )
      Builtins.y2milestone(
        "Disk with boot partition: %1, using for MBR",
        boot_disk
      )
      boot_disk
    end

    # ConfigureLocation()
    # Where to install the bootloader.
    # Returns the type of device where to install: one of "boot", "root", "mbr", "mbr_md"
    # Also sets internal global variable selected_location to this.
    #
    #
    # @return [String] type of location proposed to bootloader
    # FIXME: replace with grub_ConfigureLocation() when lilo et al. have
    # changed to stop using selected_location and loader_device.
    def ConfigureLocation
      # configure stage1 only on non-EFI systems
      ::Bootloader::Stage1.new.propose.to_s if Yast::Bootloader.getLoaderType == "grub2"
    end

    # Detect /boot and / (root) partition devices
    # If loader_device is empty or the device is not available as a boot
    # partition, also calls ConfigureLocation to configure loader_device, set
    # selected_location and set the activate flag if needed
    # all these settings are stored in internal variables
    def DetectDisks
      location_reconfigure = BootStorage.detect_disks

      return if location_reconfigure == :ok
      # if already proposed, then empty location is intention of user
      if location_reconfigure == :empty && BootCommon.was_proposed
        # unless autoinstall where we do not allow empty boot devices (bnc#948258)
        return unless Mode.auto
      end

      ConfigureLocation()
    end

    # Update global options of bootloader
    # modifies internal sreuctures
    def UpdateGlobals
      if Ops.get(@globals, "timeout", "") == ""
        Ops.set(@globals, "timeout", "8")
      end

      nil
    end

    # Get the summary of disks order for the proposal
    # @return [String] a line for the summary (or nil if not intended to be shown)
    def DiskOrderSummary
      order = BootStorage.DisksOrder
      ret = nil
      if Ops.greater_than(Builtins.size(order), 1)
        ret = Builtins.sformat(
          # part of summary, %1 is a list of hard disks device names
          _("Order of Hard Disks: %1"),
          Builtins.mergestring(order, ", ")
        )
      end
      ret
    end
  end
end
