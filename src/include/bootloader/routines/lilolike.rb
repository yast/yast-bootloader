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
      @selected_location = "mbr" # default to mbr
      @loader_device = @mbrDisk
      # check whether the /boot partition
      #  - is primary:			    is_logical	-> false
      #  - is on the first disk (with the MBR):  disk_is_mbr -> true
      tm = Storage.GetTargetMap
      dp = Storage.GetDiskPartition(BootStorage.BootPartitionDevice)
      disk = Ops.get_string(dp, "disk", "")
      disk_is_mbr = disk == @mbrDisk
      dm = Ops.get_map(tm, disk, {})
      partitions = Ops.get_list(dm, "partitions", [])
      is_logical = false
      extended = nil
      needed_devices = [BootStorage.BootPartitionDevice]
      md_info = Md2Partitions(BootStorage.BootPartitionDevice)
      if md_info != nil && Ops.greater_than(Builtins.size(md_info), 0)
        disk_is_mbr = false
        needed_devices = Builtins.maplist(md_info) do |d, b|
          pdp = Storage.GetDiskPartition(d)
          p_disk = Ops.get_string(pdp, "disk", "")
          disk_is_mbr = true if p_disk == @mbrDisk
          d
        end
      end
      Builtins.y2milestone("Boot partition devices: %1", needed_devices)
      Builtins.foreach(partitions) do |p|
        if Ops.get(p, "type") == :extended
          extended = Ops.get_string(p, "device")
        elsif Builtins.contains(needed_devices, Ops.get_string(p, "device", "")) &&
            Ops.get(p, "type") == :logical
          is_logical = true
        end
      end
      Builtins.y2milestone("/boot is on 1st disk: %1", disk_is_mbr)
      Builtins.y2milestone("/boot is in logical partition: %1", is_logical)
      Builtins.y2milestone("The extended partition: %1", extended)

      exit = 0
      # if is primary, store bootloader there
      if disk_is_mbr && !is_logical
        @selected_location = "boot"
        @loader_device = BootStorage.BootPartitionDevice
        @activate = true
        @activate_changed = true
      elsif Ops.greater_than(Builtins.size(needed_devices), 1)
        @loader_device = "mbr_md"
        @selected_location = "mbr_md"
      end

      if !Builtins.contains(
          BootStorage.possible_locations_for_stage1,
          @loader_device
        )
        @selected_location = "mbr" # default to mbr
        @loader_device = @mbrDisk
      end

      Builtins.y2milestone(
        "ConfigureLocation (%1 on %2)",
        @selected_location,
        @loader_device
      )

      # set active flag
      if @selected_location == "mbr"
        # we are installing into MBR:
        # if there is an active partition, then we do not need to activate
        # one (otherwise we do)
        @activate = Builtins.size(Storage.GetBootPartition(@mbrDisk)) == 0
      else
        # if not installing to MBR, always activate
        @activate = true
      end

      @selected_location
    end

    # Detect /boot and / (root) partition devices
    # If loader_device is empty or the device is not available as a boot
    # partition, also calls ConfigureLocation to configure loader_device, set
    # selected_location and set the activate flag if needed
    # all these settings are stored in internal variables
    def DetectDisks
      need_location_reconfigure = BootStorage.detect_disks
      ConfigureLocation() if need_location_reconfigure
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
