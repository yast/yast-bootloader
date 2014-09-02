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

      Yast.import "Arch"
      Yast.import "Mode"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "BootArch"
      Yast.import "Map"

      Yast.include include_target, "bootloader/routines/i386.rb"


      # fallback list for kernel flavors (adapted from Kernel.ycp), used if we have
      # no better information
      # order is from special to general, but prefer "default" in favor of "xen"
      # FIXME: handle "rt" and "vanilla"?
      # bnc #400526 there is not xenpae anymore...
      @generic_fallback_flavors = [
        "s390",
        "iseries64",
        "ppc64",
        "bigsmp",
        "default",
        "xen"
      ]
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
          BootStorage.getPartitionList(:boot, getLoaderType(false)),
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
      # #151501: AutoYaST needs to know the activate flag and the
      # loader_device; jsrain also said this code is probably a bug:
      # commenting out, but this may need to be changed and made dependent
      # on a "clone" flag (i.e. make the choice to provide minimal (i.e. let
      # YaST do partial proposals on the target system) or maximal (i.e.
      # stay as closely as possible to this system) info in the AutoYaST XML
      # file)
      # if (Mode::config ())
      #    return;
      mp = Storage.GetMountPoints

      mountdata_boot = Ops.get_list(mp, "/boot", Ops.get_list(mp, "/", []))
      mountdata_root = Ops.get_list(mp, "/", [])

      Builtins.y2milestone("mountPoints %1", mp)
      Builtins.y2milestone("mountdata_boot %1", mountdata_boot)

      BootStorage.RootPartitionDevice = Ops.get_string(mp, ["/", 0], "")

      if BootStorage.RootPartitionDevice == ""
        Builtins.y2error("No mountpoint for / !!")
      end

      # if /boot changed, re-configure location
      BootStorage.BootPartitionDevice = Ops.get_string(
        mountdata_boot,
        0,
        BootStorage.RootPartitionDevice
      )

      if @mbrDisk == "" || @mbrDisk == nil
        # mbr detection.
        @mbrDisk = FindMBRDisk()
      end

      if @loader_device == nil || @loader_device == "" ||
          !Builtins.contains(
            BootStorage.getPartitionList(:boot, getLoaderType(false)),
            @loader_device
          )
        ConfigureLocation()
      end

      nil
    end

    # Run delayed updates
    #
    # This is used by perl-Bootloader when it cannot remove sections from the
    # bootloader configuration from the postuninstall-script of the kernel. It
    # writes a command to a delayed update script that is then called here to
    # remove these sections.
    #
    # The script is deleted after execution.
    def RunDelayedUpdates
      scriptname = "/boot/perl-BL_delayed_exec"
      cmd = Builtins.sformat("test -x %1 && { cat %1 ; %1 ; }", scriptname)

      Builtins.y2milestone("running delayed update command: %1", cmd)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("command returned %1", out)

      cmd = Builtins.sformat("rm -f %1", scriptname)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

      nil
    end

    def getLargestSwapPartition
      swap_sizes = getSwapPartitions
      swap_parts = Builtins.maplist(swap_sizes) { |name, size| name }
      swap_parts = Builtins.sort(swap_parts) do |a, b|
        Ops.greater_than(Ops.get(swap_sizes, a, 0), Ops.get(swap_sizes, b, 0))
      end
      Ops.get(swap_parts, 0, "")
    end


    # Update global options of bootloader
    # modifies internal sreuctures
    def UpdateGlobals
      if Ops.get(@globals, "timeout", "") == ""
        Ops.set(@globals, "timeout", "8")
      end

      # bnc #380509 if autoyast profile includes gfxmenu == none
      # it will be deleted
      if Ops.get(@globals, "gfxmenu", "") != "none"
        Ops.set(@globals, "gfxmenu", "/boot/message")
      end

      nil
    end

    # Update the gfxboot/message/... line if exists
    def UpdateGfxMenu
      message = Ops.get(@globals, "gfxmenu", "")
      if message != "" && Builtins.search(message, "(") == nil
        if -1 == SCR.Read(path(".target.size"), message)
          @globals = Builtins.remove(@globals, "gfxmenu")
        end
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

    # Convert XEN boot section to normal linux section
    # if intalling in domU (bnc #436899)
    #
    # @return [Boolean] true if XEN section is converted to linux section

    def ConvertXENinDomU
      ret = false
      if !Arch.is_xenU
        Builtins.y2milestone(
          "Don't convert XEN section - it is not running in domU"
        )
        return ret
      end

      # tmp sections
      tmp_sections = []

      Builtins.foreach(@sections) do |sec|
        # bnc#604401 Xen para-virtualized guest boots native kernel
        # set XEN boot section to default
        if Ops.get_string(sec, "type", "") == "xen" ||
            Ops.get_string(sec, "type", "") == "image"
          if Builtins.search(
              Builtins.tolower(Ops.get_string(sec, "image", "")),
              "xen"
            ) != nil
            Builtins.y2milestone(
              "Set \"xen\" image: %1 to default",
              Ops.get_string(sec, "name", "")
            )
            Ops.set(@globals, "default", Ops.get_string(sec, "name", ""))
          end
        end
        if Ops.get_string(sec, "type", "") != "xen"
          tmp_sections = Builtins.add(tmp_sections, sec)
        else
          # convert XEN section to linux section
          Builtins.y2milestone("Converting XEN section in domU: %1", sec)
          Ops.set(sec, "type", "image")
          Ops.set(sec, "original_name", "linux")
          sec = Builtins.remove(sec, "xen") if Builtins.haskey(sec, "xen")
          if Builtins.haskey(sec, "xen_append")
            sec = Builtins.remove(sec, "xen_append")
          end
          if Builtins.haskey(sec, "lines_cache_id")
            sec = Builtins.remove(sec, "lines_cache_id")
          end

          Builtins.y2milestone("Converted XEN section in domU: %1", sec)

          tmp_sections = Builtins.add(tmp_sections, sec)

          ret = true
        end
      end

      @sections = deep_copy(tmp_sections)
      ret
    end
  end
end
