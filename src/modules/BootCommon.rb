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
require "yast"

module Yast
  class BootCommonClass < Module
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "GfxMenu"
      Yast.import "HTML"
      Yast.import "Mode"
      Yast.import "PackageSystem"
      Yast.import "Storage"
      Yast.import "String"
      Yast.import "Popup"
      Yast.import "Package"
      Yast.import "PackagesProposal"
      Yast.import "BootStorage"

      Yast.import "Linuxrc"


      # General bootloader settings

      # map of global options and types for new perl-Bootloader interface
      @global_options = {}

      # map of section options and types for new perl-Bootloader interface
      @section_options = {}

      # boolean value indicate if "/" is on logical
      # and primary /boot doesn't exist

      @boot_device_on_logical = false

      # map of global options and values
      @globals = {}

      # list of section
      @sections = []

      # Saved change time from target map - proposal

      @cached_settings_base_data_change_time = nil


      # device to save loader stage 1 to
      # NOTE: this variable is being phased out. The boot_* keys in the globals map
      # are now used to remember the selected boot location. Thus, we now have a
      # list of selected loader devices. It can be generated from the information in
      # the boot_* keys and the global variables (Boot|Root|Extended)PartitionDevice
      # and mbrDisk by calling GetBootloaderDevices().
      #FIXME: need remove to read only loader location from perl-Bootloader
      @loader_device = nil

      # proposal helping variables

      # The kind of bootloader location that the user selected last time he went to
      # the dialog. Used as a hint next time a proposal is requested, so the
      # proposal can try to satisfy the user's previous preference.
      # NOTE: this variable is being phased out. The boot_* keys in the globals map
      # will be used to remember the last selected location.
      # Currently, valid values are: mbr, boot, root, floppy, mbr_md, none
      #FIXME: need remove to read only loader location from perl-Bootloader
      @selected_location = nil



      # These global variables and functions are needed in included files

      # Parameters of currently used bootloader
      @current_bootloader_attribs = {}

      # Parameters of all bootloaders
      @bootloader_attribs = {}

      # Name of currently edited section
      @current_section_name = nil

      # Index of current section, -1 for new created section
      @current_section_index = -1

      # Curtrently edited section -- tmp store
      @current_section = {}


      # Option types for different bootloaders
      @opt_types = {}

      # device holding MBR for bootloader
      @mbrDisk = ""

      # was currently edited section changed (== true)
      @one_section_changed = false

      # Backup original MBR before installing bootloader
      @backup_mbr = false

      # Activate bootloader partition during installation?
      @activate = false


      # FATE #303548 - Grub: limit device.map to devices detected by BIOS
      # Ask user if he wants to edit again bootloader settings
      # It is used if device.map is limited and "boot" disk is out of range
      # The range is the first 8 devices
      @ask_user = false

      # Replace MBR with generic code after bootloader installation?
      @repl_mbr = false

      # Kernel parameters at previous detection
      @kernelCmdLine = ""

      # were settings changed (== true)
      @changed = false


      @installed_version = {}
      @update_version = {}

      @edited_files = {}
      # common variables

      # type of bootloader to configure/being configured
      # shall be one of "lilo", "grub", "elilo", "ppc", "zipl", "grub2", "grub2-efi"
      @loader_type = nil
      @secure_boot = nil

      # sysconfig variables

      # installation proposal help variables

      # List of partitions deleted in primary proposal
      @del_parts = []

      # variables for storing data

      # saving mode setting functions

      # map of save mode settings
      @write_settings = {}

      # summary dialog state

      # Show verbose summary output
      @verbose = false

      # ui help variables


      @additional_failsafe_params = ""


      # other variables

      # Settings of other bootloaders used when switching bootloader
      @other_bl = {}

      # bootloader installation variables

      # Was the activate flag changed by user?
      @activate_changed = false
      # Save everything, not only changed settings
      @save_all = false

      # state variables

      # was the propose function called (== true)
      @was_proposed = false
      # Were module settings read (== true)
      @was_read = false
      # Was bootloader location changed? (== true)
      @location_changed = false
      # Were configuration files manually edited and chamged?
      @files_edited = false
      # Has been files edited warning already shown?
      @files_edited_warned = false
      # time of last change of partitioning
      @partitioning_last_change = 0
      # true if memtest was removed by user (manually) during the installation
      # proposal
      #FIXME correct comment
      @removed_sections = []

      # The name of the default section as it was read
      @read_default_section_name = ""

      # Types of sections that should be updated (changed device names)
      # FIXME: see FIXME in lilolike.ycp:899
      @update_section_types = ["floppy", "other"]
      #    = [ "linux", "failsafe", "initrd", "floppy" ];

      # List of all supported bootloaders
      @bootloaders = [
        "lilo",
        "grub",
        "elilo",
        "zipl",
        "ppc",
        "grub2",
        "grub2-efi"
      ]

      # FATE#305008: Failover boot configurations for md arrays with redundancy
      # if true enable redundancy for md array
      @enable_md_array_redundancy = nil

      # FATE#305557: Enable SELinux for 11.2
      #  if true create /selinux directory
      @enable_selinux = false
      # help message and dscription definitions
      Yast.include self, "bootloader/routines/popups.rb"
      Yast.include self, "bootloader/routines/misc.rb"
      # FIXME: there are other archs than i386, this is not 'commmon'
      Yast.include self, "bootloader/routines/lilolike.rb"
      Yast.include self, "bootloader/routines/lib_iface.rb"
    end

    # interface to bootloader library




    # FIXME 2x functions should not be finally here...
    # Check whether XEN is selected for installation resp. selected
    # @return [Boolean] true of XEN installed/selected
    def XenPresent
      ret = !Builtins.contains(@removed_sections, "xen") &&
        (Mode.test ||
          Mode.normal && Pkg.IsProvided("xen") && Pkg.IsProvided("kernel-xen") ||
          !Mode.normal && Pkg.IsSelected("xen") && Pkg.IsSelected("kernel-xen"))

      Builtins.y2milestone("ret: %1", ret)
      ret
    end

    # Function check if trusted grub is selected
    # or installed return true if is selected/installed
    # and add trusted_grub to globals
    # @return [Boolean] true if trusted grub is selected/installed

    def isTrustedGrub
      ret = false
      if Mode.normal
        if Pkg.IsProvided("trustedgrub") || Package.Installed("trustedgrub")
          ret = true
          Ops.set(@globals, "trusted_grub", "true")
        end
      else
        if Pkg.IsSelected("trustedgrub")
          ret = true
          Ops.set(@globals, "trusted_grub", "true")
        end
      end
      ret
    end


    # Get the size of memory for XEN's domain 0
    # @return the memory size in kB
    def Dom0MemorySize
      memory = Convert.convert(
        SCR.Read(path(".probe.memory")),
        :from => "any",
        :to   => "list <map>"
      )

      Builtins.y2milestone("memory: %1", memory)
      memory_size = 0

      Builtins.foreach(memory) do |info|
        # internal class, main memory
        if Ops.get_integer(info, "class_id", 0) == 257 &&
            Ops.get_integer(info, "sub_class_id", 0) == 2
          minf = Ops.get_list(info, ["resource", "phys_mem"], [])
          Builtins.foreach(minf) do |i|
            memory_size = Ops.add(memory_size, Ops.get_integer(i, "range", 0))
          end
        end
      end 

      # size in kB lowered 64 MB for XEN itself
      memory_size = Ops.subtract(Ops.divide(memory_size, 1024), 64 * 1024)
      Builtins.y2milestone("Memory size for XEN domain 0: %1", memory_size)
      memory_size
    end


    # Create section for linux kernel
    # @param [String] title string the section name to create (untranslated)
    # @return a map describing the section
    def CreateLinuxSection(title)
      ret = {
        "name"          => translateSectionTitle(title),
        "original_name" => title,
        "type"          => "image",
        "__auto"        => true,
        "__changed"     => true
      }

      if title == "memtest86"
        if MemtestPresent()
          Ops.set(ret, "image", "/boot/memtest.bin")
          Ops.set(ret, "__devs", [BootStorage.BootPartitionDevice])
          return deep_copy(ret)
        else
          return {}
        end
      end

      resume = BootArch.ResumeAvailable ? getLargestSwapPartition : ""
      # try to use label or udev id for device name... FATE #302219
      if resume != "" && resume != nil
        resume = BootStorage.Dev2MountByDev(resume)
      end


      # FIXME:
      # This only works in the installed system (problem with GetFinalKernel()),
      # in all other cases we use the symlinks.

      kernel_fn = ""
      initrd_fn = ""

      if Mode.normal
        # Find out the file names of the "real" kernel and initrd files, with
        # version etc. pp. whatever (currently version-flavor) attached.
        # FIXME: also do this for xen and xenpae kernels as found below
        #
        # Note: originally, we wanted to find out the kernel file names during
        # installation proposal when the files are not yet installed. But not
        # all the necessary interfaces work at that time. Now, this variant is
        # only run in the "running system", and could as well look at the
        # installed files.
        #

        # First of all, we have to initialize the RPM database
        Pkg.TargetInit(
          "/", # installed system
          false
        ) # don't create a new RPM database

        # Then, get the file names in the "selected" kernel package,
        kernel_package = Kernel.ComputePackage
        files = Pkg.PkgGetFilelist(kernel_package, :installed)
        Builtins.y2milestone(
          "kernel package %1 has these files: %2",
          kernel_package,
          files
        )

        # then find the first file that matches the arch-dependent kernel file
        # name prefix and the initrd filename prefix.
        kernel_prefix = Ops.add("/boot/", Kernel.GetBinary)
        initrd_prefix = "/boot/initrd"

        files_filtered = Builtins.filter(files) do |file|
          Builtins.substring(file, 0, Builtins.size(kernel_prefix)) == kernel_prefix
        end


        # Sort the filtered files, thus the image strings by length, the big ones
        # at the beginning, the small ones at the end of the list.
        # So, the first element of the sorted list files_filtered is the image string
        # containing the version and flavor.
        files_filtered = Builtins.sort(files_filtered) do |kbig, ksmall|
          Ops.greater_than(Builtins.size(kbig), Builtins.size(ksmall))
        end

        kernel_fn = Ops.get(files_filtered, 0, "")

        files_filtered = Builtins.filter(files) do |file|
          Builtins.substring(file, 0, Builtins.size(initrd_prefix)) == initrd_prefix &&
            !Builtins.regexpmatch(file, "-kdump$")
        end

        # Sort the filtered files, thus the initrd strings by length, the big ones
        # at the beginning, the small ones at the end of the list.
        # So, the first element of the sorted list files_filtered is the initrd string
        # containing the version and flavor.
        files_filtered = Builtins.sort(files_filtered) do |ibig, ismall|
          Ops.greater_than(Builtins.size(ibig), Builtins.size(ismall))
        end

        initrd_fn = Ops.get(files_filtered, 0, "")

        kernel_fn = "/boot/vmlinuz" if kernel_fn == "" || kernel_fn == nil

        initrd_fn = "/boot/initrd" if initrd_fn == "" || initrd_fn == nil

        # read commandline options for kernel
        cmd = Convert.convert(
          SCR.Read(path(".proc.cmdline")),
          :from => "any",
          :to   => "list <string>"
        )

        vga = nil

        # trying to find "vga" option
        Builtins.foreach(cmd) do |key|
          vga = key if Builtins.issubstring(key, "vga=")
          Builtins.y2milestone("key: %1", key)
        end
        Builtins.y2milestone("vga from command line: %1", vga)
        mode = []

        # split vga=value
        if vga != nil && vga != ""
          mode = Builtins.splitstring(Builtins.tostring(vga), "=")
        end

        vgamode = nil

        # take value if exist
        if Ops.greater_than(Builtins.size(mode), 1) &&
            Ops.get(mode, 0, "") == "vga"
          vgamode = Ops.get(mode, 1)
        end

        # add value of vga into proposal (if exist)
        if vgamode != nil && vgamode != ""
          Ops.set(ret, "vgamode", vgamode)
          Builtins.y2milestone("vga mode: %1", vgamode)
        end
      else
        # the links are shown in the proposal; at the end of an installation,
        # in bootloader_finish, they will be resolved to the real filenames
        kernel_fn = Ops.add("/boot/", Kernel.GetBinary)
        initrd_fn = "/boot/initrd"
      end
      # done: kernel_fn and initrd_fn are the results
      Builtins.y2milestone("kernel_fn: %1 initrd_fn: %2", kernel_fn, initrd_fn)

      ret = Convert.convert(
        Builtins.union(
          ret,
          {
            "image"  => kernel_fn,
            "initrd" => initrd_fn,
            # try to use label or udev id for device name... FATE #302219
            "root"   => BootStorage.Dev2MountByDev(
              BootStorage.RootPartitionDevice
            ),
            "append" => title == "failsafe" ?
              BootArch.FailsafeKernelParams :
              BootArch.DefaultKernelParams(resume),
            "__devs" => [
              BootStorage.BootPartitionDevice,
              BootStorage.RootPartitionDevice
            ]
          }
        ),
        :from => "map",
        :to   => "map <string, any>"
      )
      if BootArch.VgaAvailable && Kernel.GetVgaType != ""
        # B#352020 kokso: - Graphical failsafe mode
        #if (title == "failsafe")
        #    ret["vga"] = "normal";
        #else
        Ops.set(ret, "vgamode", Kernel.GetVgaType) 

        # B#352020 end
      end
      if title == "xen"
        Ops.set(ret, "type", "xen")
        Ops.set(ret, "xen_append", "")

        Ops.set(ret, "xen", "/boot/xen.gz")
        Ops.set(
          ret,
          "image",
          Ops.add(Ops.add("/boot/", Kernel.GetBinary), "-xen")
        )
        Ops.set(ret, "initrd", "/boot/initrd-xen")
      end
      deep_copy(ret)
    end

    # generic versions of bootloader-specific functions

    # Export bootloader settings to a map
    # @return bootloader settings
    def Export
      exp = {
        "global"     => remapGlobals(@globals),
        "sections"   => remapSections(@sections),
        "device_map" => BootStorage.remapDeviceMap(BootStorage.device_mapping)
      }
      if !(@loader_type == "grub" || @loader_type == "grub2")
        Ops.set(exp, "repl_mbr", @repl_mbr)
        Ops.set(exp, "activate", @activate)
      end

      deep_copy(exp)
    end

    # Import settings from a map
    # @param [Hash] settings map of bootloader settings
    # @return [Boolean] true on success
    def Import(settings)
      settings = deep_copy(settings)
      @globals = Ops.get_map(settings, "global", {})
      @sections = Ops.get_list(settings, "sections", [])

      # FIXME: for grub, repl_mbr is replaced by globals["generic_mbr"]; same
      # for activate; remove the following when no bootloader uses these
      # variables any more
      if !(@loader_type == "grub" || @loader_type == "grub2")
        @repl_mbr = Ops.get_boolean(settings, "repl_mbr", false)
        @activate = Ops.get_boolean(settings, "activate", false)
      end
      BootStorage.device_mapping = Ops.get_map(settings, "device_map", {})
      true
    end

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      bl = getLoaderType(false)
      return true if bl == "none"
      InitializeLibrary(reread, bl)
      ReadFiles(avoid_reading_device_map) if reread
      @sections = GetSections()
      @globals = GetGlobal()
      isTrustedGrub
      BootStorage.device_mapping = GetDeviceMap()
      @read_default_section_name = ""
      Builtins.foreach(@sections) do |s|
        if Ops.get_string(s, "original_name", "") == "linux" &&
            @read_default_section_name == ""
          @read_default_section_name = Ops.get_string(s, "name", "")
        end
      end

      # convert device names in device map to the kernel device names
      BootStorage.device_mapping = Builtins.mapmap(BootStorage.device_mapping) do |k, v|
        # if we update from version 9 (SLES9), first convert old-style persistent
        # device names to new-style persistent device names ("p1" -> "-part1")
        # NOTE: this is idempotent; but other device name translation
        # (e.g. libata migration) is not, so it will be done later
        if Mode.update && Ops.get_integer(@installed_version, "major", 0) == 9
          k = Storage.SLES9PersistentDevNames(k)
          Builtins.y2milestone(
            "devmap: dev name after SLES9 persistent dev name translation: %1",
            k
          )
        end
        { BootStorage.Dev2MountByDev(k) => v }
      end

      # convert custom boot device names in globals to the kernel device names
      # also, for legacy bootloaders like LILO that still pass device names,
      # convert the stage1_dev
      @globals = Builtins.mapmap(@globals) do |k, v|
        if k == "stage1_dev" || Builtins.regexpmatch(k, "^boot_.*custom$")
          # see comments above
          if Mode.update && Ops.get_integer(@installed_version, "major", 0) == 9
            v = Storage.SLES9PersistentDevNames(v)
            Builtins.y2milestone(
              "globals: dev name after SLES9 persistent dev name translation: %1",
              v
            )
          end
          next { k => BootStorage.Dev2MountByDev(v) }
        else
          next { k => v }
        end
      end


      # convert root device names in sections to kernel device names, if
      # possible
      @sections = Builtins.maplist(@sections) do |s|
        rdev = Ops.get_string(s, "root", "")
        # see comments above
        if Mode.update && Ops.get_integer(@installed_version, "major", 0) == 9
          rdev = Storage.SLES9PersistentDevNames(rdev)
          Builtins.y2milestone(
            "sections: dev name after SLES9 persistent dev name translation: %1",
            rdev
          )
        end
        # bnc#533782 - after changing filesystem label system doesn't boot
        if Ops.get_string(s, "append", "") != ""
          Ops.set(
            s,
            "append",
            remapResume(Ops.get_string(s, "append", ""), true)
          )
        end
        Ops.set(s, "root", BootStorage.Dev2MountByDev(rdev))
        deep_copy(s)
      end
      true
    end

    # Reset bootloader settings
    # @param [Boolean] init boolean true to repropose also device map
    def Reset(init)
      @sections = []
      @globals = {}
      # DetectDisks ();
      @repl_mbr = false
      @activate = false
      @activate_changed = false
      @removed_sections = []
      @was_proposed = false
      BootStorage.ProposeDeviceMap if getLoaderType(false) == "grub" if init

      nil
    end

    # Propose bootloader settings
    def Propose
      Builtins.y2error("No generic propose function available")

      nil
    end

    # bnc# 346576 - Bootloader configuration doesn't work for serial output
    # Function check if settings need to remove gfxmenu
    #
    # @return [Boolean] - true if gfxmenu needs to be removed

    def removeGFXMenu
      if Ops.get(@globals, "trusted_grub", "") == "true" &&
          Builtins.haskey(@globals, "gfxmenu")
        Builtins.y2milestone("Remove gfxmenu -> selected trusted grub")
        return true
      end

      if Ops.get(@globals, "serial") != "" && Ops.get(@globals, "serial") != nil
        Builtins.y2milestone("Remove gfxmenu -> defined serial console")
        return true
      end

      if Ops.get(@globals, "gfxmenu", "") == "none"
        Builtins.y2milestone("Remove gfxmenu -> disabled gfxmenu")
        return true
      end
      false
    end

    # bnc #390659 - autoyast bootloader config: empty settings are ignored (memtest)
    #
    # Check if sections inlcude section for memtest
    # if yes delete all unnecessary keys like initrd, vgamode, append...
    def checkMemtest
      out = []

      Builtins.foreach(@sections) do |s|
        if Builtins.search(Ops.get_string(s, "image", ""), "memtest") != nil
          tmp_s = {}
          Ops.set(tmp_s, "image", Ops.get_string(s, "image", ""))
          Ops.set(
            tmp_s,
            "original_name",
            Ops.get_string(s, "original_name", "")
          )
          Ops.set(tmp_s, "name", Ops.get_string(s, "name", ""))
          Ops.set(tmp_s, "__changed", Ops.get_boolean(s, "__changed", false))
          Ops.set(tmp_s, "__auto", Ops.get_boolean(s, "__auto", false))
          Ops.set(tmp_s, "type", Ops.get_string(s, "type", ""))
          Builtins.y2milestone(
            "Updating memtest section from: %1 to: %2",
            s,
            tmp_s
          )
          out = Builtins.add(out, tmp_s)
        else
          out = Builtins.add(out, s)
        end
      end

      @sections = deep_copy(out)

      nil
    end
    # Save all bootloader configuration files to the cache of the PlugLib
    # PlugLib must be initialized properly !!!
    # @param [Boolean] clean boolean true if settings should be cleaned up (checking their
    #  correctness, supposing all files are on the disk)
    # @param [Boolean] init boolean true to init the library
    # @param [Boolean] flush boolean true to flush settings to the disk
    # @return [Boolean] true if success
    def Save(clean, init, flush)
      if clean
        RemoveUnexistentSections("", "")
        UpdateAppend()
        UpdateGfxMenu()
      end

      ret = true

      bl = getLoaderType(false)

      InitializeLibrary(init, bl)

      return true if bl == "none"

      @globals = Builtins.remove(@globals, "gfxmenu") if removeGFXMenu

      # bnc#589433 -  Install grub into root (/) partition gives error
      if Ops.get(@globals, "boot_custom") == "" &&
          Builtins.haskey(@globals, "boot_custom")
        @globals = Builtins.remove(@globals, "boot_custom")
      end

      # FIXME: give mountby information to perl-Bootloader (or define some
      # better interface), so that perl-Bootloader can use mountby device names
      # for these devices instead. Tracked in bug #248162.

      # convert XEN section to linux section id running in domU
      # bnc #436899
      # bnc #604401 Xen para-virtualized guest boots native kernel
      # I have to call it before updating of BootCommon::globals to my_globals
      # bnc #604401c14
      ConvertXENinDomU()

      # convert custom boot device names in globals to the device names
      # indicated by "mountby"
      # also, for legacy bootloaders like LILO that still pass device names,
      # convert the stage1_dev
      my_globals = Builtins.mapmap(@globals) do |k, v|
        if k == "stage1_dev" || Builtins.regexpmatch(k, "^boot_.*custom$")
          next { k => BootStorage.Dev2MountByDev(v) }
        else
          next { k => v }
        end
      end

      # convert device names in device map to the device names indicated by
      # "mountby"

      Builtins.y2milestone(
        "device map before mapping %1",
        BootStorage.device_mapping
      )
      my_device_mapping = Builtins.mapmap(BootStorage.device_mapping) do |k, v|
        { BootStorage.Dev2MountByDev(k) => v }
      end
      Builtins.y2milestone("device map after mapping %1", my_device_mapping)

      if VerifyMDArray()
        if @enable_md_array_redundancy != true &&
            Builtins.haskey(my_globals, "boot_md_mbr")
          my_globals = Builtins.remove(my_globals, "boot_md_mbr")
        end
        if @enable_md_array_redundancy == true &&
            !Builtins.haskey(my_globals, "boot_md_mbr")
          Ops.set(my_globals, "boot_md_mbr", BootStorage.addMDSettingsToGlobals)
        end
      else
        if Builtins.haskey(@globals, "boot_md_mbr")
          my_globals = Builtins.remove(my_globals, "boot_md_mbr")
        end
      end
      # add check if there is memtest and delete from memtest section
      # keys like append, initrd etc...
      checkMemtest
      Builtins.y2milestone("SetSecureBoot %1", @secure_boot)
      ret = ret && SetSecureBoot(@secure_boot)
      ret = ret && DefineMultipath(BootStorage.multipath_mapping)
      ret = ret && SetDeviceMap(my_device_mapping)
      ret = ret && SetSections(@sections)
      ret = ret && SetGlobal(my_globals)
      ret = ret && CommitSettings() if flush

      # write settings to /etc/sysconfig/bootloader
      WriteToSysconf(false)

      ret
    end
    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      if getLoaderType(false) == "none"
        return [
          HTML.Colorize(getLoaderName(getLoaderType(false), :summary), "red")
        ]
      end
      targetMap = Storage.GetTargetMap
      boot_target = Ops.get_map(targetMap, @loader_device, {})
      target_name = ""
      if boot_target == {}
        target_name = @loader_device
        if target_name == "mbr_md"
          mbrs = Builtins.maplist(
            Md2Partitions(BootStorage.BootPartitionDevice)
          ) do |d, id|
            p_dev = Storage.GetDiskPartition(d)
            Ops.get_string(p_dev, "disk", "")
          end
          # summary part, %1 is a list of device names
          target_name = Builtins.sformat(
            _("Master boot records of disks %1"),
            Builtins.mergestring(mbrs, ", ")
          )
        end
      else
        target_name = Ops.get_string(boot_target, "name", "disk")
      end
      target_name = AddMbrToDescription(target_name, @loader_device)

      result = []
      # summary text, %1 is bootloader name (eg. LILO)
      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Boot Loader Type: %1"),
          getLoaderName(getLoaderType(false), :summary)
        )
      )
      # summary text, location is location description (eg. /dev/hda)
      result = Builtins.add(
        result,
        Builtins.sformat(_("Location: %1"), target_name)
      )
      sects = []
      Builtins.foreach(@sections) do |s|
        title = Ops.get_string(s, "name", "")
        # section name "suffix" for default section
        _def = title == Ops.get(@globals, "default", "") ? _(" (default)") : ""
        sects = Builtins.add(
          sects,
          String.EscapeTags(Builtins.sformat("+ %1%2", title, _def))
        )
      end
      # summary text. %1 is list of bootloader sections
      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Sections:<br>%1"),
          Builtins.mergestring(sects, "<br>")
        )
      )
      if @loader_device == "/dev/null"
        # summary text
        result = Builtins.add(
          result,
          _("Do not install boot loader; just create \nconfiguration files")
        )
      end

      deep_copy(result)
    end

    # Update read settings to new version of configuration files
    def Update
      Builtins.y2debug("No generic update function available")

      nil
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      Builtins.y2error("No generic write function available")
      false
    end


    # end of generic versions of bootloader-specific functions
    #-----------------------------------------------------------------------------
    # common functions start

    # bootloader type handling functions

    # Set attributes of specified bootloader to variable containing
    # attributes of currently used bootloader, call its initializer
    # @param [String] loader_type string loader type to initialize
    def setCurrentLoaderAttribs(loader_type)
      Builtins.y2milestone("Setting attributes for bootloader %1", loader_type)
      # testsuite hack
      return if Mode.test
      if loader_type == nil
        Builtins.y2error("Setting loader type to nil, this is wrong")
        return
      end

      # FIXME: this should be blInitializer in switcher.ycp for code cleanness
      # and understandability
      if Ops.get(@bootloader_attribs, [loader_type, "initializer"]) != nil
        Builtins.y2milestone("Running bootloader initializer")
        toEval = Convert.convert(
          Ops.get(@bootloader_attribs, [loader_type, "initializer"]),
          :from => "any",
          :to   => "void ()"
        )
        toEval.call
        Builtins.y2milestone("Initializer finished")
      else
        Builtins.y2error("No initializer found for >>%1<<", loader_type)
        @current_bootloader_attribs = {}
      end

      @current_bootloader_attribs = Convert.convert(
        Builtins.union(
          @current_bootloader_attribs,
          Builtins.eval(Ops.get(@bootloader_attribs, loader_type, {}))
        ),
        :from => "map",
        :to   => "map <string, any>"
      )

      nil
    end

    # Check whether loader with specified name is supported
    # @param [String] loader string name of loader to check
    # @return [String] the loader name if supported, "none" otherwise
    def SupportedLoader(loader)
      return loader if Builtins.contains(@bootloaders, loader)
      "none"
    end

    # Get currently used bootloader, detect if not set yet
    # @param [Boolean] recheck boolean force checking bootloader
    # @return [String] botloader type
    def getLoaderType(recheck)
      return @loader_type if !recheck && @loader_type != nil
      # read bootloader to use from disk
      if Mode.update || Mode.normal || Mode.repair
        @loader_type = Convert.to_string(
          SCR.Read(path(".sysconfig.bootloader.LOADER_TYPE"))
        )
        if @loader_type != nil && @loader_type != ""
          @loader_type = "grub2" if @loader_type == "s390"
          @loader_type = "ppc" if @loader_type == "lilo" && Arch.ppc
          Builtins.y2milestone(
            "Sysconfig bootloader is %1, using",
            @loader_type
          )
          @loader_type = SupportedLoader(@loader_type)
          Builtins.y2milestone(
            "Sysconfig bootloader is %1, using",
            @loader_type
          )
          setCurrentLoaderAttribs(@loader_type)
          return @loader_type
        end
        if Mode.update
          # FIXME: this is extremely broken, no arch specifica here !!
          if Arch.i386
            # no sysconfig variable -> old version installed -> use LILO
            @loader_type = "lilo"
            @loader_type = SupportedLoader(@loader_type)
            setCurrentLoaderAttribs(@loader_type)
            return @loader_type
          end
        end
      end
      # detect bootloader
      @loader_type = Convert.to_string(SCR.Read(path(".probe.boot_arch")))
      @loader_type = "grub2" if @loader_type == "s390"
      # ppc uses grub2 (fate #315753)
      @loader_type = "grub2" if @loader_type == "ppc"
      # suppose grub2 should superscede grub ..
      @loader_type = "grub2" if @loader_type == "grub"
      Builtins.y2milestone("Bootloader detection returned %1", @loader_type)
      # lslezak@: Arch::is_xenU() returns true only in PV guest
      if Arch.is_uml || Arch.is_xenU
        # y2milestone ("Not installing any bootloader for UML/Xen PV");
        # loader_type = "none";
        # bnc #380982 - pygrub cannot boot kernel
        # added installation of bootloader
        Builtins.y2milestone(
          "It is XEN domU and the bootloader should be installed"
        )
      end
      if (Arch.i386 || Arch.x86_64) && Linuxrc.InstallInf("EFI") == "1"
        # use grub2-efi as default bootloader for x86_64/i386 EFI
        # previously we use elilo
        @loader_type = "grub2-efi"
      end

      @loader_type = SupportedLoader(@loader_type)
      Builtins.y2milestone("Detected bootloader %1", @loader_type)
      setCurrentLoaderAttribs(@loader_type)
      @loader_type
    end


    # set type of bootloader
    # @param [String] bootloader string type of bootloader
    def setLoaderType(bootloader)
      if bootloader == nil
        Builtins.y2milestone("Resetting the loader type")
        @loader_type = nil
      end
      Builtins.y2milestone("Setting bootloader to >>%1<<", bootloader)
      if bootloader != nil && Builtins.contains(@bootloaders, bootloader) &&
          !Mode.test
        # added kexec-tools fate# 303395
        # if kexec option is equal 0 or running live installation
        # doesn't install kexec-tools

        bootloader_packages = Ops.get_list(
          @bootloader_attribs,
          [bootloader, "required_packages"],
          []
        )
        if !Mode.live_installation && Linuxrc.InstallInf("kexec_reboot") != "0"
          bootloader_packages = Builtins.add(bootloader_packages, "kexec-tools")
        end

        # replace grub with trustedgrub
        if Ops.get(@globals, "trusted_grub", "") == "true"
          if Builtins.contains(bootloader_packages, "grub")
            bootloader_packages = Builtins.filter(bootloader_packages) do |key|
              key != "grub"
            end
          end

          bootloader_packages = Builtins.add(bootloader_packages, "trustedgrub")
        end

        Builtins.y2milestone("Bootloader packages: %1", bootloader_packages)

        # don't configure package manager during autoinstallation preparing
        if Mode.normal && !(Mode.config || Mode.repair)
          PackageSystem.InstallAll(bootloader_packages)
        elsif Stage.initial
          pkg_added = false
          Builtins.foreach(bootloader_packages) do |p|
            Builtins.y2milestone("Select bootloader package: %1", p)
            PackagesProposal.AddResolvables("yast2-bootloader", :package, [p])
            pkg_added = true
          end
        end
      elsif !Mode.test
        Builtins.y2error("Unknown bootloader")
      end
      @loader_type = bootloader
      setCurrentLoaderAttribs(@loader_type) if @loader_type != nil
      Builtins.y2milestone("Loader type set")

      nil
    end

    def checkSecureBoot
      ret = false
      sbvar = "/sys/firmware/efi/vars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c/data"
      sbvar_avail = 0 ==
        Convert.to_integer(
          SCR.Execute(path(".target.bash"), Ops.add("test -e ", sbvar))
        )

      if sbvar_avail
        cmd = Builtins.sformat("test `od -An -N1 -t u1 %1` -eq 1", sbvar)
        ret = 0 == Convert.to_integer(SCR.Execute(path(".target.bash"), cmd))
      end

      ret
    end

    def getSystemSecureBootStatus(recheck)
      return @secure_boot if !recheck && @secure_boot != nil

      if Mode.update || Mode.normal || Mode.repair
        sb = Convert.to_string(
          SCR.Read(path(".sysconfig.bootloader.SECURE_BOOT"))
        )

        if sb != nil && sb != ""
          @secure_boot = sb == "yes" ? true : false
          return @secure_boot
        end
      end

      @secure_boot = checkSecureBoot
      @secure_boot
    end

    def setSystemSecureBootStatus(enable)
      #     if (enable && enable != secure_boot)
      #     {
      #         // don't configure package manager during autoinstallation preparing
      #         if (Mode::normal () && (! (Mode::config () || Mode::repair ())))
      #         {
      #             y2milestone ("Install shim");
      #             PackageSystem::InstallAll (["shim"]);
      #         }
      #         else if (Stage::initial () )
      #         {
      #             y2milestone ("AddResolvables shim");
      #             PackagesProposal::AddResolvables ("yast2-bootloader", `package, ["shim"]);
      #         }
      #     }
      Builtins.y2milestone("Set secure boot: %2 => %1", enable, @secure_boot)
      @secure_boot = enable

      nil
    end

    # List bootloaders available for configured architecture
    # @return a list of bootloaders
    def getBootloaders
      if Mode.config
        return [
          "grub",
          "lilo",
          "elilo",
          "zipl",
          "ppc",
          "grub2",
          "grub2-efi",
          "default",
          "none"
        ]
      end
      ret = [
        getLoaderType(false),
        Convert.to_string(SCR.Read(path(".probe.boot_arch")))
      ]
      if Arch.i386 || Arch.x86_64
        ret = Convert.convert(
          # don't add lilo (fate #314886)
          Builtins.merge(ret, ["grub2"]),
          :from => "list",
          :to   => "list <string>"
        )
        if Arch.x86_64
          ret = Convert.convert(
            Builtins.merge(ret, ["grub2-efi"]),
            :from => "list",
            :to   => "list <string>"
          )
        end
      end
      if Arch.s390
        ret = ["grub2", "zipl"]
      end
      # in order not to display it twice when "none" is selected
      ret = Builtins.filter(ret) { |l| l != "none" }
      ret = Builtins.toset(ret)
      ret = Builtins.add(ret, "none")
      deep_copy(ret)
    end

    # Search for section passed
    # @return [Fixnum] index number

    def Section2Index(section_name)
      index = -1
      sectnum = -1

      Builtins.foreach(@sections) do |s|
        index = Ops.add(index, 1)
        sectnum = index if Ops.get_string(s, "name", "") == section_name
      end

      Builtins.y2milestone("ret: %1", sectnum)
      sectnum
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Verify if proposal includes md array with 2 diferent disks
    #
    # @return [Boolean] true if there is md array based on 2 disks
    def VerifyMDArray
      ret = false
      if Builtins.haskey(@globals, "boot_md_mbr")
        md_array = Ops.get(@globals, "boot_md_mbr", "")
        disks = Builtins.splitstring(md_array, ",")
        disks = Builtins.filter(disks) { |v| v != "" }
        if Builtins.size(disks) == 2
          Builtins.y2milestone("boot_md_mbr includes 2 disks: %1", disks)
          ret = true
        end
      end
      ret
    end

    publish :variable => :global_options, :type => "map <string, any>"
    publish :variable => :section_options, :type => "map <string, any>"
    publish :variable => :boot_device_on_logical, :type => "boolean"
    publish :variable => :globals, :type => "map <string, string>"
    publish :variable => :sections, :type => "list <map <string, any>>"
    publish :variable => :cached_settings_base_data_change_time, :type => "integer"
    publish :variable => :loader_device, :type => "string"
    publish :variable => :selected_location, :type => "string"
    publish :variable => :current_bootloader_attribs, :type => "map <string, any>"
    publish :variable => :bootloader_attribs, :type => "map <string, map <string, any>>"
    publish :variable => :current_section_name, :type => "string"
    publish :variable => :current_section_index, :type => "integer"
    publish :variable => :current_section, :type => "map <string, any>"
    publish :variable => :opt_types, :type => "map <string, map <string, string>>"
    publish :variable => :mbrDisk, :type => "string"
    publish :variable => :one_section_changed, :type => "boolean"
    publish :variable => :backup_mbr, :type => "boolean"
    publish :variable => :activate, :type => "boolean"
    publish :variable => :ask_user, :type => "boolean"
    publish :variable => :repl_mbr, :type => "boolean"
    publish :variable => :kernelCmdLine, :type => "string"
    publish :variable => :changed, :type => "boolean"
    publish :variable => :installed_version, :type => "map <string, any>"
    publish :variable => :update_version, :type => "map <string, any>"
    publish :variable => :edited_files, :type => "map <string, string>"
    publish :variable => :del_parts, :type => "list <string>"
    publish :variable => :write_settings, :type => "map"
    publish :variable => :verbose, :type => "boolean"
    publish :variable => :other_bl, :type => "map"
    publish :variable => :activate_changed, :type => "boolean"
    publish :variable => :save_all, :type => "boolean"
    publish :variable => :was_proposed, :type => "boolean"
    publish :variable => :was_read, :type => "boolean"
    publish :variable => :location_changed, :type => "boolean"
    publish :variable => :files_edited, :type => "boolean"
    publish :variable => :files_edited_warned, :type => "boolean"
    publish :variable => :partitioning_last_change, :type => "integer"
    publish :variable => :removed_sections, :type => "list <string>"
    publish :variable => :read_default_section_name, :type => "string"
    publish :variable => :update_section_types, :type => "list <string>"
    publish :variable => :bootloaders, :type => "list <string>"
    publish :variable => :enable_md_array_redundancy, :type => "boolean"
    publish :variable => :enable_selinux, :type => "boolean"
    publish :function => :getLoaderType, :type => "string (boolean)"
    publish :function => :getSystemSecureBootStatus, :type => "boolean (boolean)"
    publish :function => :getBootloaders, :type => "list <string> ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :CreateLinuxSection, :type => "map <string, any> (string)"
    publish :function => :UpdateSerialConsole, :type => "string (string, string)"
    publish :function => :examineMBR, :type => "string (string)"
    publish :function => :ThinkPadMBR, :type => "boolean (string)"
    publish :function => :VerifyMDArray, :type => "boolean ()"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
    publish :function => :DetectDisks, :type => "void ()"
    publish :function => :getBootPartition, :type => "string ()"
    publish :function => :getLoaderName, :type => "string (string, symbol)"
    publish :function => :getBooleanAttrib, :type => "boolean (string)"
    publish :function => :getAnyTypeAttrib, :type => "any (string, any)"
    publish :function => :updateTimeoutPopupForFloppy, :type => "void (string)"
    publish :function => :remapGlobals, :type => "map <string, string> (map <string, string>)"
    publish :function => :remapSections, :type => "list <map <string, any>> (list <map <string, any>>)"
    publish :function => :isBlank, :type => "boolean (string)"
    publish :function => :splitPath, :type => "list <string> (string)"
    publish :function => :GetBootloaderDevice, :type => "string ()"
    publish :function => :GetBootloaderDevices, :type => "list <string> ()"
    publish :function => :IsPartitionBootable, :type => "boolean (string)"
    publish :function => :InstallingToFloppy, :type => "boolean ()"
    publish :function => :getKernelParamFromLine, :type => "string (string, string)"
    publish :function => :setKernelParamToLine, :type => "string (string, string, string)"
    publish :function => :myToInteger, :type => "integer (any)"
    publish :function => :updateMBR, :type => "boolean ()"
    publish :function => :restoreMBR, :type => "boolean (string)"
    publish :function => :UpdateKernelParams, :type => "string (string)"
    publish :function => :getSwapPartitions, :type => "map <string, integer> ()"
    publish :function => :translateSectionTitle, :type => "string (string)"
    publish :function => :UpdateInstallationKernelParameters, :type => "void ()"
    publish :function => :GetAdditionalFailsafeParams, :type => "string ()"
    publish :function => :GetAdditionalKernelParams, :type => "string ()"
    publish :function => :ListAdditionalKernelParams, :type => "list <string> ()"
    publish :function => :UpdateGfxMenuContents, :type => "boolean ()"
    publish :function => :UpdateDevice, :type => "string (string)"
    publish :function => :MemtestPresent, :type => "boolean ()"
    publish :function => :BootloaderInstallable, :type => "boolean ()"
    publish :function => :PartitionInstallable, :type => "boolean ()"
    publish :function => :findRelativeDefaultLinux, :type => "string ()"
    publish :function => :isDefaultBootSectioLinux, :type => "boolean (string)"
    publish :function => :WriteToSysconf, :type => "void (boolean)"
    publish :function => :getBootDisk, :type => "string ()"
    publish :function => :HandleConsole, :type => "void ()"
    publish :function => :HandleConsole2, :type => "void ()"
    publish :function => :UpdateProposalFromClient, :type => "boolean ()"
    publish :function => :DiskOrderSummary, :type => "string ()"
    publish :function => :DisksChanged, :type => "boolean ()"
    publish :function => :KeepMBR, :type => "boolean (string)"
    publish :function => :AddFirmwareToBootloader, :type => "boolean (string)"
    publish :function => :i386Summary, :type => "list <string> ()"
    publish :function => :i386LocationProposal, :type => "void ()"
    publish :function => :PostUpdateMBR, :type => "boolean ()"
    publish :function => :FindMBRDisk, :type => "string ()"
    publish :function => :Md2Partition, :type => "string (string)"
    publish :function => :RunDelayedUpdates, :type => "void ()"
    publish :function => :FixGlobals, :type => "void ()"
    publish :function => :FixSections, :type => "void (void ())"
    publish :function => :UpdateSections, :type => "void ()"
    publish :function => :UpdateGlobals, :type => "void ()"
    publish :function => :UpdateDeviceMap, :type => "void ()"
    publish :function => :RemoveUnexistentSections, :type => "void (string, string)"
    publish :function => :UpdateAppend, :type => "void ()"
    publish :function => :UpdateGfxMenu, :type => "void ()"
    publish :function => :DefineMultipath, :type => "boolean (map <string, string>)"
    publish :function => :SetDiskInfo, :type => "void ()"
    publish :function => :InitializeLibrary, :type => "boolean (boolean, string)"
    publish :function => :SetSections, :type => "boolean (list <map <string, any>>)"
    publish :function => :GetSections, :type => "list <map <string, any>> ()"
    publish :function => :SetGlobal, :type => "boolean (map <string, string>)"
    publish :function => :GetGlobal, :type => "map <string, string> ()"
    publish :function => :SetDeviceMap, :type => "boolean (map <string, string>)"
    publish :function => :GetDeviceMap, :type => "map <string, string> ()"
    publish :function => :bootloaderError, :type => "void (string)"
    publish :function => :ReadFiles, :type => "boolean (boolean)"
    publish :function => :CommitSettings, :type => "boolean ()"
    publish :function => :UpdateBootloader, :type => "boolean ()"
    publish :function => :SetSecureBoot, :type => "boolean (boolean)"
    publish :function => :InitializeBootloader, :type => "boolean ()"
    publish :function => :GetFilesContents, :type => "map <string, string> ()"
    publish :function => :SetFilesContents, :type => "boolean (map <string, string>)"
    publish :function => :XenPresent, :type => "boolean ()"
    publish :function => :isTrustedGrub, :type => "boolean ()"
    publish :function => :Dom0MemorySize, :type => "integer ()"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :setCurrentLoaderAttribs, :type => "void (string)"
    publish :function => :setLoaderType, :type => "void (string)"
    publish :function => :setSystemSecureBootStatus, :type => "void (boolean)"
    publish :function => :Section2Index, :type => "integer (string)"
  end

  BootCommon = BootCommonClass.new
  BootCommon.main
end
