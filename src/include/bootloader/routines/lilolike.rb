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

    # Check whether disk settings were changed since last checking
    # @return [Boolean] true if needs to recheck
    def DisksChanged
      return false if Mode.config
      mp = Storage.GetMountPoints
      actual_root = Ops.get_string(mp, ["/", 0], "")
      actual_boot = Ops.get_string(mp, ["/boot", 0], actual_root)

      # don't change configuration if '/' and '/boot' were not changed
      # and location is "floppy", "mbr" or "boot"
      if actual_boot == BootStorage.BootPartitionDevice &&
          actual_root == BootStorage.RootPartitionDevice &&
          @selected_location != "custom" &&
          @selected_location != "" &&
          @selected_location != nil
        return false
      end

      all_partitions = BootStorage.getPartitionList(:boot, getLoaderType(false))

      if !Builtins.contains(all_partitions, @loader_device)
        Builtins.y2milestone("Location should be set again")
        return true
      end
      false
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



    # function check all partitions and it tries to find /boot partition
    # if it is MD Raid and soft-riad return correct device for analyse MBR
    # @param list<map> list of partitions
    # @return [String] device for analyse MBR
    def soft_MDraid_boot_disk(partitions)
      partitions = deep_copy(partitions)
      result = ""
      boot_device = ""
      if BootStorage.BootPartitionDevice != nil &&
          BootStorage.BootPartitionDevice != ""
        boot_device = BootStorage.BootPartitionDevice
      else
        boot_device = BootStorage.RootPartitionDevice
      end

      Builtins.foreach(partitions) do |p|
        if Ops.get_string(p, "device", "") == boot_device
          if Ops.get(p, "type") == :sw_raid &&
              Ops.get_string(p, "fstype", "") == "MD Raid"
            device_1 = Ops.get_string(p, ["devices", 0], "")
            Builtins.y2debug("device_1: %1", device_1)
            dp = Storage.GetDiskPartition(device_1)
            Builtins.y2debug("dp: %1", dp)
            result = Ops.get_string(dp, "disk", "")
          end
        end
      end
      Builtins.y2milestone(
        "Device for analyse MBR from soft-raid (MD-Raid only): %1",
        result
      )
      result
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

      # keep_mbr, if the MBR contains special code that needs to be kept,
      #           like Thinkpad boot code (and ATM only Thinkpad boot code
      #           is recognized)
      keep_mbr = KeepMBR(@loader_device)

      exit = 0
      # if is primary, store bootloader there
      if disk_is_mbr && !is_logical
        @selected_location = "boot"
        @loader_device = BootStorage.BootPartitionDevice
        @activate = true
        @activate_changed = true

        # check if there is raid and if it soft-raid select correct device for analyse MBR
        # bnc #398356
        if Ops.greater_than(Builtins.size(needed_devices), 1)
          disk = soft_MDraid_boot_disk(partitions)
        end
        disk = Ops.get_string(dp, "disk", "") if disk == ""
        out = examineMBR(disk)

        @repl_mbr = out != "vista" && !keep_mbr
      elsif Ops.greater_than(Builtins.size(needed_devices), 1)
        @loader_device = "mbr_md"
        @selected_location = "mbr_md"
      end

      if keep_mbr
        if is_logical && extended != nil
          @loader_device = extended
        else
          @loader_device = BootStorage.BootPartitionDevice
        end
        @selected_location = "boot"
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

    # Converts the md device to the list of devices building it
    # @param [String] md_device string md device
    # @return a map of devices (from device name to BIOS ID or nil if
    #   not detected) building the md device
    def Md2Partitions(md_device)
      ret = {}
      tm = Storage.GetTargetMap
      Builtins.foreach(tm) do |disk, descr_a|
        descr = Convert.convert(
          descr_a,
          :from => "any",
          :to   => "map <string, any>"
        )
        bios_id_str = Ops.get_string(descr, "bios_id", "")
        bios_id = 256 # maximum + 1 (means: no bios_id found)
        bios_id = Builtins.tointeger(bios_id) if bios_id_str != ""
        partitions = Ops.get_list(descr, "partitions", [])
        Builtins.foreach(partitions) do |partition|
          if Ops.get_string(partition, "used_by_device", "") == md_device
            d = Ops.get_string(partition, "device", "")
            Ops.set(ret, d, bios_id)
          end
        end
      end
      Builtins.y2milestone("Partitions building %1: %2", md_device, ret)
      deep_copy(ret)
    end

    # Converts the md device to the first of its members
    # @param [String] md_device string md device
    # @return [String] one of devices building the md array
    def Md2Partition(md_device)
      devices = Md2Partitions(md_device)
      return md_device if Builtins.size(devices) == 0
      minimal = 129 # maximum + 2
      found = ""
      Builtins.foreach(devices) do |k, v|
        if Ops.less_than(v, minimal)
          found = k
          minimal = v
        end
      end
      found
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

    # Fix global section of lilo-like bootloader
    #
    # This currently only tries to fix the "default" key if necessary. It is when
    # the referenced section does not exist anymore or during a system update when
    # a special comment in the bootloader configuration tells us that we have to
    # update the "default" key. An empty "default" value is not changed, because
    # this means that no default is wanted.
    #
    # If we need to fix the "default" key we take the following steps:
    #
    #  - If we are fixing the configuration at the end of an update and the
    #    special key "former_default_image_flavor" exists, try to set the default
    #    to the first "linux.*" section with an image of this flavor (preferring
    #    "linux" entries over possibly older "linux-.*" entries).
    #
    #  - Otherwise go through a list of fallback kernel flavours and use the first
    #    "linux.*" section that contains a matching image (preferring "linux"
    #    entries over possibly older "linux-.*" entries).
    #
    #  - Otherwise, simply use the first section as the default section.
    def FixGlobals
      defaultv = Ops.get(@globals, "default", "")
      first = ""

      Builtins.y2milestone("fixing default section")

      # nothing to do if default is empty
      return if defaultv == ""

      # does default section exist?
      exists = false
      Builtins.foreach(@sections) do |s|
        label = Ops.get_string(s, "name", "")
        exists = true if label == defaultv
        first = label if first == ""
      end

      if exists &&
          (!Mode.update ||
            Ops.get(@globals, "former_default_image_flavor") == nil)
        return
      end

      # need to fix "default"
      old_entry_found = false
      found_name = ""
      fallback_flavors = deep_copy(@generic_fallback_flavors)

      if Mode.update && Ops.get(@globals, "former_default_image_flavor") != nil
        fallback_flavors = Builtins.prepend(
          fallback_flavors,
          Ops.get(@globals, "former_default_image_flavor", "")
        )

        # former_default_image_flavor is removed at the end of the update
        @globals = Builtins.remove(@globals, "former_default_image_flavor")
      end

      Builtins.y2milestone("looking for image flavors %1", fallback_flavors)
      Builtins.foreach(fallback_flavors) do |flavor|
        next if found_name != ""
        Builtins.foreach(@sections) do |s|
          label = Ops.get_string(s, "name", "")
          if Builtins.regexpmatch(
              Ops.get_string(s, "original_name", ""),
              "^linux(-.*)?$"
            ) ||
              Builtins.regexpmatch(
                Ops.get_string(s, "image", ""),
                Ops.add(Ops.add("^.*-", flavor), "$")
              )
            # found, if we have not yet found a match, or the previously
            # found one was for an "old" entry and we now found a "new"
            # one
            if found_name == "" ||
                old_entry_found &&
                  Builtins.regexpmatch(
                    Ops.get_string(s, "original_name", ""),
                    "^linux$"
                  )
              found_name = label
              if Builtins.regexpmatch(
                  Ops.get_string(s, "original_name", ""),
                  "^linux-.*$"
                )
                old_entry_found = true
              else
                old_entry_found = false
              end
            end
          end
        end
      end

      if found_name != ""
        Ops.set(@globals, "default", found_name)
      else
        Ops.set(@globals, "default", first)
      end

      Builtins.y2milestone(
        "setting new default section to: %1",
        Ops.get(@globals, "default")
      )

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


    # Fix section of lilo-like bootloader
    def FixSections(create_sections)
      create_sections = deep_copy(create_sections)
      parts = BootStorage.getPartitionList(:parts_old, getLoaderType(false))
      if @partitioning_last_change != Storage.GetTargetChangeTime && @files_edited
        displayFilesEditedPopup
        @files_edited_warned = true
        return
      end

      # save old sections and propose new ones in global "sections"
      # (the updated list of old sections will become the new section list in
      # the end)
      old_sect_list = deep_copy(@sections)

      create_sections.call

      # new_sect is a map with elements containing: "type" -> section
      new_sect = Builtins.listmap(@sections) do |s|
        label = Ops.get_string(s, "name", "")
        type = Ops.get_string(s, "original_name", label)
        { type => s }
      end

      # remember a list with all the section "types" in the old section list
      # (needed later in this function to find newly created sections)
      old_section_types = Builtins.maplist(old_sect_list) do |s|
        Ops.get_string(s, "original_name", "")
      end

      # in the old list of sections:
      #	- only keep sections that the user created (no "__auto", or false) or
      #	  changed ("__changed") in the UI
      #  - replace unchanged sections with ones we proposed just now (if
      #    available)
      #  - also notify user when devices for a "changed by user" section are
      #    unavailable or would now be proposed differently (and mark section as
      #    "created by user")
      old_sect_list = Builtins.maplist(old_sect_list) do |s|
        label = Ops.get_string(s, "name", "")
        type = Ops.get_string(s, "original_name", label)
        if !Ops.get_boolean(s, "__auto", false)
          Builtins.y2milestone("Leaving section %1", label)
          next deep_copy(s)
        elsif !Ops.get_boolean(s, "__changed", false)
          Builtins.y2milestone(
            "Recreating section %1, new is %2",
            label,
            Ops.get(new_sect, type, {})
          )
          next Ops.get(new_sect, type, {})
        else
          # section was created by us, then changed by the user:
          #	- keep it, except if no newly created section of same type can
          #	  be found (which probably means we have a bug, because
          #	  "__auto" says we created the old section as well)
          #  - maybe notify user to check it (and then mark it as a "user
          #    defined section")
          Builtins.y2milestone("Warning on section %1", label)
          cont = true
          # if "non-standard" section name and a used device is not
          # available anymore, notify user
          if type != "linux" && type != "failsafe" && type != "memtest86"
            Builtins.foreach(Ops.get_list(s, "__devs", [])) do |n|
              cont = false if !Builtins.contains(parts, n)
            end
          end
          # find section of same type in newly created sections;
          # if not found (which should not happen, since according to the
          # "__auto" key we created it) delete this section
          new_this_section = Ops.get(new_sect, type, {})
          if new_this_section == {}
            Builtins.y2warning(
              "Warning, could not find freshly proposed section" +
                "corresponding to section %1, deleting it",
              Ops.get_string(s, "name", "")
            )
            next {}
          end
          # if the devices for this section and the freshly created one of
          # the same type are different, notify user
          new_devs = Builtins.toset(
            Ops.get_list(new_this_section, "__devs", [])
          )
          old_devs = Builtins.toset(Ops.get_list(s, "__devs", []))
          if Builtins.size(new_devs) != Builtins.size(old_devs)
            cont = false
          else
            Builtins.foreach(old_devs) do |d|
              cont = false if !Builtins.contains(new_devs, d)
            end
          end
          # display info popup for this section;
          # also, next time we come through this function, consider this
          # section as a section created by the user (and leave it as it is)
          if !cont
            Ops.set(s, "__auto", false)
            displayDiskChangePopup(label)
          end
          next deep_copy(s)
        end
      end

      # in newly created sections, fix "resume" parameter in append line if
      # necessary
      Builtins.y2milestone("Checking for sections using the resume parameter")
      @sections = Builtins.maplist(@sections) do |s|
        append = Ops.get_string(s, "append", "")
        resume = getKernelParamFromLine(append, "resume")
        if resume != "" && resume != nil &&
            !Builtins.haskey(getSwapPartitions, resume)
          # points to unexistent swap partition
          # bnc# 335526 - Installing memtest with lilo screws up installation
          if Builtins.search(Ops.get_string(s, "original_name", ""), "memtest") == nil
            append = setKernelParamToLine(
              append,
              "resume",
              BootStorage.Dev2MountByDev(getLargestSwapPartition)
            )
            Ops.set(s, "append", append)
          end
        end
        deep_copy(s)
      end

      # now add sections from newly created ones that were unknown before in the
      # old section list, if not already removed by the user (#170469)
      Builtins.foreach(@sections) do |s|
        label = Ops.get_string(s, "name", "")
        type = Ops.get_string(s, "original_name", label)
        if !Builtins.contains(old_section_types, type) &&
            !Builtins.contains(@removed_sections, type)
          Builtins.y2milestone("Adding new section \"%1\": %2", label, s)
          old_sect_list = Builtins.add(old_sect_list, s)
          next deep_copy(s)
        end
      end

      # Strange (I must have misread the code here):
      # if a newly created section uses one or more deleted devices, and a
      # section of that type does not exist anymore in the old section list, add
      # it to the old section list
      Builtins.y2milestone(
        "Checking for sections needing some of %1",
        @del_parts
      )
      to_remove = []
      Builtins.foreach(@sections) do |s|
        devs = Ops.get_list(s, "__devs", [])
        label = Ops.get_string(s, "name", "")
        Builtins.y2milestone("Section %1 needs %2", label, devs)
        to_add = false
        Builtins.foreach(devs) do |d|
          to_add = true if Builtins.contains(@del_parts, d)
        end
        if to_add
          old_sect = Builtins.listmap(old_sect_list) { |os| { label => os } }

          if label != "" && !Builtins.haskey(old_sect, label)
            Builtins.y2milestone("Adding %1", s)
            to_remove = Builtins.add(to_remove, label)
            old_sect_list = Builtins.add(old_sect_list, s)
          end
        end
      end

      # FIXME: BUG: looks like a bug to remove a list of labels from the list of
      # deleted devices
      @del_parts = Convert.convert(
        difflist(@del_parts, to_remove),
        :from => "list",
        :to   => "list <string>"
      )

      # cleanup: throw away empty sections
      old_sect_list = Builtins.filter(old_sect_list) { |s| s != {} }

      # save old, updated section list as proposed section list
      @sections = deep_copy(old_sect_list)

      nil
    end

    # Update in section old devices to new kernel format
    # @param [Hash{String => Object}] section section to modify
    def UpdateDeviceForSection(section)
      section = deep_copy(section)
      if Ops.get_string(section, "type", "") == "image" ||
          Ops.get_string(section, "type", "") == "xen"
        #check if we update correct image and if update is needed
        if UpdateDevice(Ops.get_string(section, "root", "nonexisted")) ==
            BootStorage.RootPartitionDevice &&
            Ops.get_string(section, "root", "") !=
              UpdateDevice(Ops.get_string(section, "root", ""))
          Builtins.y2milestone(
            "Updating device of section %1",
            Ops.get_string(section, "name", "name")
          )
          Ops.set(
            section,
            "root",
            UpdateDevice(Ops.get_string(section, "root", ""))
          )

          resume = getKernelParamFromLine(
            Ops.get_string(section, "append", ""),
            "resume"
          )
          if resume != "false"
            Builtins.y2milestone(
              "Updating resume device of section %1",
              Ops.get_string(section, "name", "name")
            )
            resume = UpdateDevice(resume)
            Ops.set(
              section,
              "append",
              setKernelParamToLine(
                Ops.get_string(section, "append", ""),
                "resume",
                BootStorage.Dev2MountByDev(resume)
              )
            )
          end
          Ops.set(section, "__modified", "1")
        end
      end

      nil
    end

    # Update sections of bootloader menu (removes obsolete thinks and
    # place for ugly hacks (but doesn't efect zypper dup))
    # modifies internal structures
    # label update is done in perl-Bootloader during updating kernel
    # Purpose is don't break anything, but expect that previous state is
    # working
    def UpdateSections
      Builtins.foreach(@sections) do |section|
        #remap device names from hd* to sd*
        UpdateDeviceForSection(section)
      end

      nil
    end

    # global void UpdateSections (boolean replace,
    #     map<string,any>(string) create_linux_section)
    # {
    #     list<map<string,any> > out = BootCommon::sections;
    #     list<string> recreated = [];
    #     boolean linux_resume_added = false;
    #
    #     map<string,any> default_sect = create_linux_section ("linux");
    #     string default_kernel = default_sect["image"]:"";
    #     string default_initrd = default_sect["initrd"]:"";
    #     string default_name = default_sect["name"]:"";
    #
    #     list<string> sections_to_recreate = ["linux", "failsafe", "memtest86"];
    #     if (getLoaderType (false) == "grub")
    #     {
    # 	sections_to_recreate = add (sections_to_recreate, "xen");
    #     }
    #
    #     // if replace == true,  replace all sections that have a type in
    #     //                      sections_to_recreate with a newly created version
    #     // if replace == false, only adjust "append" line of "linux" section
    #     //
    #     // at the end of the loop, if one of the sections_to_recreate does not
    #     // exist, create it
    #     foreach (string t, sections_to_recreate, {
    # 	map<string,any> m = create_linux_section (t);
    # 	boolean f_changed = false;
    # 	out = maplist (map<string,any> s, out, {
    # 	    string label = s["name"]:"";
    # 	    string sect_type = s["original_name"]:"";
    # 	    if (sect_type == "")
    # 		sect_type = label;
    # 	    if (sect_type == t)
    # 	    {
    # 		f_changed = true;
    # 		if (replace && m != $[])
    # 		{
    # 		    y2milestone ("Recreated section %1: %2", label, m);
    # 		    recreated = add (recreated, label);
    # 		    return m;
    # 		}
    # 		else if (t == "linux")
    # 		{
    # 		    string append = s["append"]:"";
    # 		    string resume = BootCommon::getKernelParamFromLine (
    # 			append, "resume");
    # 		    if (! haskey (BootCommon::getSwapPartitions (), resume))
    # 		    {
    # 			append = setKernelParamToLine (append,
    # 			    "resume", BootStorage::Dev2MountByDev(getLargestSwapPartition ()));
    # 			s["append"] = append;
    # 			linux_resume_added = true;
    # 		    }
    # 		    return s;
    #                 }
    # 		else
    # 		    return s;
    # 	    }
    # 	    else
    # 	    {
    # 		return s;
    # 	    }
    # 	});
    # 	// if we did NOT change or replace the old section (meaning: there was
    # 	// none), but create_linux_section() gave us a new section, then
    # 	// prepend or append the section created by create_linux_section()
    #         if (! f_changed && m != $[])
    # 	{
    # 	    y2milestone ("Recreated section: %1", m);
    # 	    recreated = add (recreated, m["name"]:"");
    #             if (t == "linux")
    # 		out = prepend (out, m);
    #             else
    # 		out = add (out, m);
    # 	}
    #     });
    #     y2milestone ("All recreated sections: %1", recreated);
    #
    #     // for grub and replace-mode only:
    #     // convert sections that boot "other" installations (another Linux, Windows
    #     // etc.) to chainloader and configfile sections
    #     //
    #     // ! contains (sections_to_recreate, original_name)         AND
    #     // original_name == name (e.g. "openSUSE 10.3 (/dev/sdb1)") AND
    #     // haskey("image")						AND
    #     // haskey("initrd")
    #     //
    #     //  => if bootable, convert to "chainloader"
    #     //       otherwise, convert to "configfile" and hope for the best
    #     //
    #     if (getLoaderType (false) == "grub" && replace)
    #     {
    # 	y2milestone ("Converting sections for other installation to use chainloader/configfile entries...");
    # 	out = maplist (map<string,any> s, out, {
    # 	    string label = s["name"]:"";
    # 	    string sect_type = s["original_name"]:"";
    # 	    y2milestone ("label: %1, sect_type: %2", label, sect_type);
    # 	    if (!contains(sections_to_recreate, sect_type) &&
    # 		 sect_type == label &&
    # 		 haskey(s, "image") &&
    # 		 haskey(s, "initrd"))
    # 	     {
    # 		string dev = (string) s["root"]:nil;
    #
    # 		// create new entry
    # 		s = $[
    # 		    "name":		label,
    # 		    "original_name":	sect_type,
    # 		    "root":		BootStorage::Dev2MountByDev(dev)
    # 		];
    #
    # 		if (dev != nil && IsPartitionBootable(dev))
    # 		{
    # 		    //     bootable =>  chainloader
    # 		    s["noverifyroot"] = "true";
    # 		    s["chainloader"] = BootStorage::Dev2MountByDev(dev);
    # 		    s["blockoffset"] = "1";
    # 		    s["type"] = "other";
    # 		    y2milestone ("Updating section \"%1\" booting other installation to use chainloader entry", s["name"]:"");
    # 		}
    # 		else
    # 		{
    # 		    // not bootable =>  configfile
    # 		    // let's hope the config file can be found (should work at
    # 		    // least for all SUSE installations using grub)
    # 		    s["configfile"] = "/boot/grub/menu.lst";
    # 		    s["type"] = "menu";
    # 		    y2milestone ("Updating section \"%1\" booting other installation to use configfile entry", s["name"]:"");
    # 		}
    # 		return s;
    # 	    }
    # 	    else
    # 		return s;
    # 	});
    #     }
    #
    #
    #     // now adjust these keys in sections that need it:
    #     //  - kernel
    #     //  - initrd
    #     //  - name
    #     //  - device (e.g. for SATA: /dev/hda -> /dev/sda)
    #     //  - append
    #     out = maplist (map<string,any> s, out, {
    # 	string label = s["name"]:"";
    # 	string type = s["original_name"]:label;
    # 	// FIXME: do we still need to remove strings from kernel or initrd names?
    # 	//        if yes: add "image"
    # 	//        if no: remove loop
    # 	//        probably need to do this depending on the version of the old
    # 	//        installation
    # 	foreach (string key, ["image", "initrd"], {
    # 	    string value = s[key]:"";
    # 	    if (regexpmatch (value, "^.*\.shipped.*$"))
    # 	    {
    # 		value = regexpsub (value,
    # 		    "^(.*)\.shipped(.*)$", "\\1\\2");
    # 	    }
    # 	    else if (regexpmatch (value, "^.*\.suse.*$"))
    # 	    {
    # 		value = regexpsub (value,
    # 		    "^(.*)\.suse(.*)$", "\\1\\2");
    # 	    }
    # 	    // This was broken (was: s["key"] = value;)
    # 	    s[key] = value;
    # 	});
    # 	// If we did not replace the sections anyway, adjust the section titles:
    # 	// Does this section
    # 	//  - use the default kernel of a linux section \ i.e. it uses the updated kernel
    # 	//  - use the default initrd of a linux section /
    # 	//  - contain the name of the first "linux" section read from disk in
    # 	//    its name
    # 	// then, update the section name
    # 	if (!replace
    # 	    && s["image"]:"" == default_kernel
    # 	    && s["initrd"]:"" == default_initrd
    # 	    && issubstring (s["name"]:"", read_default_section_name)
    # 	    && read_default_section_name != ""
    # 	    && read_default_section_name != default_name)
    # 	{
    # 	    // idea of this:
    # 	    // orig_name == "linux":    "Linux"		    -> "<new name>"
    # 	    // orig_name == "failsafe": "Failsafe -- Linux" -> "Failsafe -- <new name>"
    # 	    y2milestone ("Updating label of section %1...", s["name"]:"");
    # 	    string old_name = s["name"]:"";
    # 	    integer i1 = search (old_name, read_default_section_name);
    # 	    integer i2 = i1 + size (read_default_section_name);
    # 	    s["name"] = substring (old_name, 0, i1) + default_name
    # 		+ substring (old_name, i2);
    # 	    y2milestone ("... to %1", s["name"]:"");
    # 	}
    #
    # 	// Update device names in sections for certain section types, if the
    # 	// section has not been recreated anyway
    # 	// FIXME: never update device names twice!
    # 	foreach (string key, ["root", "chainloader"], {
    # 	    // FIXME: for some reason, this used to update "linux" and
    # 	    // "failsafe" even if they have been recreated; but "other"
    # 	    // sections were never updated -- since there are no calls to
    # 	    // UpdateSections() with replace == false, ATM we disable updating
    # 	    // "linux" and "failsafe", and add "other", seed
    # 	    // BootCommon::update_section_types
    # 	    if ((contains (update_section_types, type)
    # 		    && ! contains (recreated, label))
    # 		|| key == "chainloader")
    # 	    {
    # 		string device = (string) s[key]:nil;
    # 		y2milestone ("Checking for update: device %1 of key %2, section %3", device, key, label);
    # 		if (device != nil)
    # 		{
    # 		    y2milestone ("Updating root/other device of section %1",
    # 			label);
    # 		    device = BootCommon::UpdateDevice (device);
    # 		    s[key] = device;
    # 		}
    # 	    }
    # 	});
    # 	if (type == "linux" && haskey (s, "append"))
    # 	{
    # 	    string option = s["append"]:"";
    # 	    foreach (string o, ListAdditionalKernelParams (), {
    # 		option = setKernelParamToLine (option, o, "false");
    # 	    });
    # 	    option = option + " " + GetAdditionalKernelParams ();
    # 	    if (getKernelParamFromLine (option, "splash") == "false")
    # 		option = setKernelParamToLine
    # 		    (option, "splash", "silent");
    # 	    s["append"] = option;
    # 	}
    # 	else if (haskey (s, "append")
    # 	    && contains (BootCommon::update_section_types, type)
    # 	   && ! contains (recreated, label))
    # 	{
    # 	    string option = s["append"]:"";
    # 	    if (type != "linux" || ! linux_resume_added)
    # 	    {
    # 		string resume
    # 		    = BootCommon::getKernelParamFromLine (
    # 			option, "resume");
    # 		if (resume != "false")
    # 		{
    # 		    y2milestone ("Updating resume device of section %1", label);
    # 		    resume = BootCommon::UpdateDevice (resume);
    # 		    option = BootCommon::setKernelParamToLine (
    # 			option, "resume", BootStorage::Dev2MountByDev(resume));
    # 		}
    # 	    }
    # 	    s["append"] = option;
    # 	}
    # 	return s;
    #     });
    #     sections = out;
    # }

    # Update global options of bootloader
    # modifies internal sreuctures
    def UpdateGlobals
      if Ops.get(@globals, "timeout", "") == ""
        Ops.set(@globals, "timeout", "8")
      end

      s1_devs = Builtins.splitstring(Ops.get(@globals, "stage1_dev", ""), ",")
      s1_devs = Builtins.maplist(s1_devs) { |d| UpdateDevice(d) }
      Ops.set(@globals, "stage1_dev", Builtins.mergestring(s1_devs, ","))

      # bnc #380509 if autoyast profile includes gfxmenu == none
      # it will be deleted
      if Ops.get(@globals, "gfxmenu", "") != "none"
        Ops.set(@globals, "gfxmenu", "/boot/message")
      end

      # now that the label for the "linux" section is not "linux" anymore, but
      # some product dependent string that can change with an update ("SLES_10"
      # -> "SLES_10_SP1"), we need to update the label in the "default" line for
      # LILO and GRUB (although the latter only needs it to correctly transform
      # back to the section number)
      # FIXME: is this needed/wanted for ELILO as well?
      FixGlobals() if Builtins.contains(["lilo", "grub"], getLoaderType(false))

      nil
    end

    # Update the device map according to changed device names
    # Read device map and store it in internal structures
    def UpdateDeviceMap
      BootStorage.device_mapping = Builtins.mapmap(BootStorage.device_mapping) do |unix, fw|
        Builtins.y2milestone(
          "Updating device in devmap entry %1 -> %2",
          unix,
          fw
        )
        unix = UpdateDevice(unix)
        { unix => fw }
      end
      Builtins.y2milestone("Updated device map: %1", BootStorage.device_mapping)

      nil
    end


    # Filter sections, remove those pointing to unexistent image
    # @param [String] path_prefix string prefix to be added to kernel path
    # @param [String] relative_path_prefix prefix to be added to relative kernel
    #  paths (without leading slash)
    def RemoveUnexistentSections(path_prefix, relative_path_prefix)
      defaultv = Ops.get(@globals, "default", "")
      first = nil
      @sections = Builtins.filter(@sections) do |s|
        label = Ops.get_string(s, "name", "")
        type = Ops.get_string(s, "original_name", "")
        if label == ""
          Builtins.y2warning("Removing section with empty title")
          defaultv = nil if label == defaultv
          next false
        end
        # FIXME the following check makes sense for all sections`
        if !Builtins.contains(["linux", "failsafe", "memtest86", "xen"], type)
          first = label if first == nil
          next true
        end
        kernel = Ops.get_string(s, "image", "")
        if kernel == ""
          first = label if first == nil
          next true
        end
        if Builtins.substring(kernel, 0, 1) == "/"
          kernel = Ops.add(path_prefix, kernel)
        else
          next true if relative_path_prefix == ""
          kernel = Ops.add(relative_path_prefix, kernel)
        end
        if SCR.Read(path(".target.size"), kernel) == -1
          Builtins.y2warning(
            "Removing section %1 with unexistent kernel %2",
            label,
            kernel
          )
          defaultv = nil if label == defaultv
          next false
        end
        first = label if first == nil
        true
      end
      defaultv = first if defaultv == nil
      Ops.set(@globals, "default", defaultv)

      nil
    end

    # Update append option if some parameters were changed
    def UpdateAppend
      @sections = Builtins.maplist(@sections) do |s|
        type = Ops.get_string(s, "original_name", "")
        if (type == "linux" || type == "global") && Ops.get(s, "append") != nil &&
            Stage.initial
          Ops.set(
            s,
            "append",
            UpdateKernelParams(Ops.get_string(s, "append", ""))
          )
        end
        deep_copy(s)
      end
      if Builtins.haskey(@globals, "append")
        Ops.set(
          @globals,
          "append",
          UpdateKernelParams(Ops.get(@globals, "append", ""))
        )
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
