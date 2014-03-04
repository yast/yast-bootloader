# encoding: utf-8

# File:
#      modules/BootGRUB.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class BootGRUBClass < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Pkg"
      Yast.import "HTML"

      # private variables

      # Shall proposal merge menus?
      @merge_level = :main

      # The variable indicate if client bootloader_preupdate
      # successful update device map
      # If success true else false

      @update_device_map_done = false

      # variables for temporary data

      # Disks order for ordering widget purproses
      @disks_order = nil

      # includes

      Yast.include self, "bootloader/grub/misc.rb"
      Yast.include self, "bootloader/routines/popups.rb"
      Yast.include self, "bootloader/grub/dialogs.rb"
      BootGRUB()
    end

    # end of mandatory functions
    #----------------------------------------------------------------------------


    # wrapper function to adjust to new grub name sceme
    def CreateLinuxSection(title)
      BootCommon.CreateLinuxSection(title)
    end


    # Check for additional kernels which could go to the proposed settings
    # @return a list of kernels to propose
    def CheckAdditionalKernels
      files = Convert.convert(
        SCR.Read(path(".target.dir"), "/boot"),
        :from => "any",
        :to   => "list <string>"
      )
      binary = Kernel.GetBinary
      kernels = Builtins.filter(files) do |k|
        Builtins.substring(k, 0, Builtins.size(binary)) == binary
      end
      kernels = Builtins.filter(kernels) do |k|
        k != "" && k != binary &&
          Builtins.regexpmatch(k, Builtins.sformat("^%1-.+$", binary))
      end
      if Builtins.contains(kernels, binary)
        defaultv = Convert.to_string(
          SCR.Read(
            path(".target.symlink"),
            Builtins.sformat("/boot/%1", binary)
          )
        )
        defaultv = "" # FIXME remove this line
        kernels = Builtins.filter(kernels) { |k| k != defaultv }
      end
      ret = Builtins.maplist(kernels) do |k|
        version = Builtins.regexpsub(
          k,
          Builtins.sformat("^%1-(.+)$", binary),
          "\\1"
        )
        info = {
          "version" => Ops.add("Kernel-", version),
          "image"   => Builtins.sformat("/boot/%1", k)
        }
        if Builtins.contains(files, Builtins.sformat("initrd-%1", version))
          Ops.set(info, "initrd", Builtins.sformat("/boot/initrd-%1", version))
        end
        deep_copy(info)
      end

      Builtins.y2milestone("Additional sections to propose: %1", ret)
      deep_copy(ret)
    end


    # Propose sections to bootloader menu
    # modifies internal structures
    #FIXME really needs refactor, it is really huge function
    def CreateSections
      Builtins.y2debug("Creating GRUB sections from scratch")
      out = []

      out = Builtins.add(out, CreateLinuxSection("linux"))
      if BootCommon.XenPresent
        out = Builtins.add(out, CreateLinuxSection("xen"))
      end

      others_ignore = []

      linux_fallback_text = "Linux other"
      fallback_num = 1

      # get a list of bootable (= "aa55" at the end of block 0) primary
      # partitions classified by partition type:
      #
      # "/dev/sda3 Linux other 1"
      # "/dev/sda4 Linux other 2"
      # "/dev/sda2 dos 1"
      # "/dev/sda3 windows 1"
      # "/dev/sda3 OS/2 Boot Manager 1"
      # "/dev/sda1 Vendor diagnostic"
      # ...
      others = Storage.GetForeignPrimary
      Builtins.y2milestone("Other primaries: %1", others)

      # get list of all Linux Partitions on all real disks except encrypted ones ( as we don't know password and bootloader cannot boot from it directly)
      other_l = Builtins.filter(
        Convert.convert(
          Storage.GetOtherLinuxPartitions,
          :from => "list",
          :to   => "list <map>"
        )
      ) { |p| Ops.get_symbol(p, "enc_type", :none) == :none }
      Builtins.y2milestone("Other linux parts: %1", other_l)


      destroyed_partitions = BootStorage.getPartitionList(:destroyed, "grub")

      tmpdir = Ops.add(
        Convert.to_string(SCR.Read(path(".target.tmpdir"))),
        "/bldetect/"
      )

      # load additional modules for filesystems used by other linux partitions,
      # if needed
      if @merge_level != :none && other_l != nil &&
          Ops.greater_than(Builtins.size(other_l), 0) &&
          0 ==
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat("test -d %1 || /bin/mkdir %1", tmpdir)
            )
        Builtins.y2milestone("Detecting other Linux parts")
        filesystems = Builtins.maplist(other_l) { |p| Ops.get(p, "used_fs", "") }
        filesystems = Builtins.toset(Builtins.filter(filesystems) { |f| f != "" })
        filesystems = Builtins.filter(filesystems) { |f| f != :ext2 }
        Builtins.y2debug("Have to modprobe %1", filesystems)
        Builtins.foreach(filesystems) do |f|
          fsmods = {
            :ext2   => "",
            :ext3   => "ext3",
            :reiser => "reiserfs",
            :xfs    => "xfs",
            :jfs    => "jfs"
          }
          modname = Ops.get_string(fsmods, f, "")
          Builtins.y2debug("Module name is %1", modname)
          if modname != ""
            r = Convert.to_integer(
              SCR.Execute(
                path(".target.bash"),
                Builtins.sformat("/sbin/modprobe %1", modname)
              )
            )
            Builtins.y2debug("result of loading %1 is %2", modname, r)
          end
        end

        Builtins.foreach(other_l) do |o|
          # Here is the general logic:
          #
          # not mountable                                                        =>  no entry
          #     mountable        bootable        has_menu_lst        name_found  =>  chainloader ("openSUSE 10.2 (/dev/sda2)")
          #     mountable        bootable                        not name_found  =>  chainloader ("Linux other 1 (/dev/sda2)")
          #     mountable    not bootable        has_menu_lst        name_found  =>  configfile  ("openSUSE 10.2 (/dev/sda2)")
          #     mountable    not bootable        has_menu_lst    not name_found  =>  configfile  ("Linux other 1 (/dev/sda2)")
          #     mountable    not bootable    not has_menu_lst                    =>  no entry
          bootable = false
          has_menu_lst = false
          menu_lst = ""
          name_found = false
          new_sect_name_prefix = ""
          BootCommon.InitializeLibrary(false, "grub")
          dev = Ops.get_string(o, "device", "")
          if dev != "" &&
              0 ==
                SCR.Execute(
                  path(".target.bash"),
                  Builtins.sformat("/bin/mount %1 %2", dev, tmpdir)
                )
            # mountable: true

            Builtins.y2milestone("Mounted %1", dev)
            filenames = []
            Builtins.foreach(
              [
                Ops.add(
                  # not needed since there is a symlink in /boot directory
                  # named boot pointing to the /boot directory
                  # this caused bug #23346 - the file was found twice
                  #			tmpdir + "grub/menu.lst",
                  tmpdir,
                  "boot/grub/menu.lst"
                )
              ]
            ) do |fn|
              if -1 != Convert.to_integer(SCR.Read(path(".target.size"), fn))
                filenames = Builtins.add(filenames, fn)
              end
            end
            Builtins.y2milestone("Found files %1", filenames)

            # bootable: ?
            bootable = BootCommon.IsPartitionBootable(dev)

            # has_menu_lst: ?
            # name_found: ?
            #
            # look for a readable menu.lst and try to extract a section
            # name from a qualifying section
            Builtins.foreach(filenames) do |f|
              next if name_found
              Builtins.y2debug("Checking file %1", f)
              fc = Convert.to_string(SCR.Read(path(".target.string"), f))
              next if fc == nil
              has_menu_lst = true
              menu_lst = Builtins.substring(f, Builtins.size(tmpdir))
              if Builtins.substring(menu_lst, 0, 1) != "/"
                menu_lst = Ops.add("/", menu_lst)
              end
              dm = Convert.to_string(
                SCR.Read(
                  path(".target.string"),
                  Builtins.regexpsub(f, "(.*)menu.lst$", "\\1device.map")
                )
              )
              Builtins.y2debug(
                "Device map file name: %1",
                Builtins.regexpsub(f, "(.*)menu.lst$", "\\1device.map")
              )
              Builtins.y2debug("Device map contents: %1", dm)
              # pass the menu.lst and device.map to the parser
              files = { "/boot/grub/menu.lst" => fc }
              next if dm == nil
              Ops.set(files, "/boot/grub/device.map", dm)
              BootCommon.InitializeLibrary(false, "grub")
              BootCommon.SetFilesContents(files)
              sects = BootCommon.GetSections
              Builtins.y2debug("Found sections %1", sects)
              # bnc #448010 grub doesn't add another installed Linux in installation
              globs = BootCommon.GetGlobal
              default_sec_name = Ops.get(globs, "default", "")
              # look only for "default" == "initial" entries, not all entries
              sects = Builtins.filter(sects) do |s|
                Ops.get(s, "initial") != nil ||
                  Ops.get(s, "name") == default_sec_name
              end
              # now find the name of the first non-broken "initial" section and get its name
              Builtins.foreach(sects) do |s|
                next if name_found
                __use = true
                # this is a heuristic: if the mounted partition or the
                # root partition referenced in the section is "new,
                # deleted or formatted", then do not use the section
                devs = [dev]
                __d = Ops.get_string(s, "root", "")
                devs = Builtins.add(devs, __d) if __d != nil && __d != ""
                devs = Builtins.filter(devs) do |d|
                  d != "" && d != nil && d != "/dev/null" && d != "false"
                end
                devs = Builtins.toset(devs)
                devs = Builtins.maplist(devs) { |d| BootCommon.UpdateDevice(d) }
                Builtins.foreach(devs) do |__d2|
                  __use = false if Builtins.contains(destroyed_partitions, __d2)
                end
                if __use
                  # no need to translate here...
                  new_sect_name_prefix = Ops.get_string(s, "name", "")
                  name_found = true
                end
              end
            end

            # now evaluate the collected information:
            #
            #     mountable        bootable        has_menu_lst        name_found  =>  chainloader ("openSUSE 10.2 (/dev/sda2)")
            #     mountable        bootable                        not name_found  =>  chainloader ("Linux other 1 (/dev/sda2)")
            #     mountable    not bootable        has_menu_lst        name_found  =>  configfile  ("openSUSE 10.2 (/dev/sda2)")
            #     mountable    not bootable        has_menu_lst    not name_found  =>  configfile  ("Linux other 1 (/dev/sda2)")
            #     mountable    not bootable    not has_menu_lst                    =>  no entry	FIXME: should this be  handled with a chainloader entry anyway, in case it becomes bootable later?

            if bootable || has_menu_lst
              # set up the new section entry
              new_sect = {
                "root"      => BootStorage.Dev2MountByDev(dev),
                "__changed" => true,
                "__auto"    => true,
                "__devs"    => [dev]
              }

              if bootable
                #     mountable        bootable                                        =>  chainloader (label: to be decided)
                Ops.set(new_sect, "noverifyroot", "true")
                Ops.set(
                  new_sect,
                  "chainloader",
                  BootStorage.Dev2MountByDev(dev)
                )
                Ops.set(new_sect, "blockoffset", "1")
                Ops.set(new_sect, "type", "other")
              else
                #     mountable    not bootable                                        =>  configfile  (label: to be decided)
                #new_sect["configfile"] = sformat("(%1)%2", dev, menu_lst);
                Ops.set(new_sect, "configfile", menu_lst)
                Ops.set(new_sect, "type", "menu")
              end

              if name_found
                #     mountable                                            name_found  =>              ("openSUSE 10.2 (/dev/sda2)")
                Ops.set(
                  new_sect,
                  "name",
                  Builtins.sformat(" %1 (%2)", new_sect_name_prefix, dev)
                )
              else
                #     mountable                                        not name_found  =>              ("Linux other 1 (/dev/sda2)")
                Ops.set(
                  new_sect,
                  "name",
                  Builtins.sformat(
                    "%1 %2 (%3)",
                    linux_fallback_text,
                    fallback_num,
                    dev
                  )
                )
                fallback_num = Ops.add(fallback_num, 1)
              end

              Ops.set(
                new_sect,
                "original_name",
                Ops.get_string(new_sect, "name", "")
              )

              out = Builtins.add(out, new_sect)
              # ignore this partition when going through the list of
              # "other", non-linux partitions in the next loop below
              others_ignore = Builtins.add(others_ignore, dev)
            end


            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat("/bin/umount %1", dev)
            )
          end
        end
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/bin/rmdir %1", tmpdir)
        )
      end



      # Go through a list of "bootable" (aa55) primary partitions that may be
      # "foreign", check that it is not one of our current boot partitions and
      # if this is not a special Thinkpad or "Vendor diagnostics" partition, add
      # a chainloader entry for it.
      if others != nil && Ops.greater_than(Builtins.size(others), 0)
        Builtins.foreach(others) do |o|
          parts = Builtins.splitstring(o, " ")
          while Ops.get_string(parts, 0, " ") == ""
            parts = Builtins.remove(parts, 0)
          end
          dev = Ops.get_string(parts, 0, "")
          Builtins.y2milestone("Checking other partition %1", dev)
          if !Builtins.contains(others_ignore, dev)
            parts = Builtins.remove(parts, 0)
            label = Builtins.mergestring(
              Convert.convert(parts, :from => "list", :to => "list <string>"),
              " "
            )

            # don't add rewritten location (#19990)
            # do not check for a bootable partition boot record: partition
            # may become bootable later
            if dev != "" && label != "" &&
                !Builtins.contains(BootCommon.GetBootloaderDevices, dev) &&
                (BootCommon.AddFirmwareToBootloader(BootCommon.mbrDisk) ||
                  label != "Vendor diagnostics" && # <- should probably be '&&' => not Thinkpad MBR AND not "Vendor diagnostics" partition type
                    label != "Vendor diagnostic")
              m = {
                "name"          => BootCommon.translateSectionTitle(label),
                "type"          => "other",
                "original_name" => label,
                "chainloader"   => BootStorage.Dev2MountByDev(dev),
                "__changed"     => true,
                "__auto"        => true,
                "__devs"        => [dev]
              }
              out = Builtins.add(out, m)
            end
          end
        end
      end


      if grub_InstallingToFloppy
        out = Builtins.add(
          out,
          {
            "name"          => BootCommon.translateSectionTitle("hard disk"),
            "original_name" => "hard_disk",
            "type"          => "other",
            "chainloader"   => BootStorage.Dev2MountByDev(BootCommon.mbrDisk),
            "__changed"     => true,
            "__auto"        => true,
            "__devs"        => []
          }
        )
      end
      out = Builtins.add(out, CreateLinuxSection("failsafe"))
      out = Builtins.add(out, CreateLinuxSection("memtest86"))

      Builtins.foreach(CheckAdditionalKernels()) do |additional|
        type = Ops.get(additional, "version", "")
        type = Builtins.sformat("%1", type)
        s = CreateLinuxSection(type)
        Ops.set(s, "image", Ops.get(additional, "image", ""))
        if Builtins.haskey(additional, "initrd")
          Ops.set(s, "initrd", Ops.get(additional, "initrd", ""))
        end
        Ops.set(s, "original_name", "linux")
        out = Builtins.add(out, s)
      end if Mode.normal(
      )
      out = Builtins.filter(out) { |s| s != {} && s != nil }
      BootCommon.sections = deep_copy(out)

      nil
    end

    # Propose global options of bootloader
    def StandardGlobals
      {
        "activate" => "true",
        "default"  => Ops.get_string(BootCommon.sections, [0, "name"], ""),
        "timeout"  => "8",
        "gfxmenu"  => "/boot/message"
      }
    end


    # general functions

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "grub")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      grub_DetectDisks
      ret = BootCommon.Read(false, avoid_reading_device_map)
      # refresh device map if not read
      if BootStorage.device_mapping == nil ||
          Builtins.size(BootStorage.device_mapping) == 0
        BootStorage.ProposeDeviceMap
      end
      # FATE#305403: Bootloader beep configuration
      # read status of acoustic signals
      if Mode.normal
        GfxMenu.ReadStatusAcousticSignal
        md_value = BootStorage.addMDSettingsToGlobals
        pB_md_value = Ops.get(BootCommon.globals, "boot_md_mbr", "")
        if pB_md_value != ""
          disks = Builtins.splitstring(pB_md_value, ",")
          disks = Builtins.filter(disks) { |v| v != "" }
          if Builtins.size(disks) == 2
            BootCommon.enable_md_array_redundancy = true
            md_value = ""
          end
          Builtins.y2milestone(
            "disks from md array (perl Bootloader): %1",
            disks
          )
        end
        if md_value != ""
          BootCommon.enable_md_array_redundancy = false
          Ops.set(BootCommon.globals, "boot_md_mbr", md_value)
          Builtins.y2milestone(
            "Add md array to globals: %1",
            BootCommon.globals
          )
        end
      end

      ret
    end


    # Reset bootloader settings
    # @param [Boolean] init boolean true to repropose also device map
    def Reset(init)
      return if Mode.autoinst
      BootCommon.Reset(init)

      nil
    end

    # Propose bootloader settings
    def Propose
      Builtins.y2debug(
        "Started propose: Glob: %1, Sec: %2",
        BootCommon.globals,
        BootCommon.sections
      )

      # if NOT was_proposed (i.e. blPropose() has not been called yet), then
      # - set up BootPartitionDevice, RootPartitionDevice
      # - if empty, set up mbrDisk
      # - if loader_device is empty or the device is not a boot device, go
      #   to grub_ConfigureLocation() and
      #	- propose
      #	    - select one loader device in the boot_* keys of the globals map
      #	    - activate (when needed, but try to be nice to Windows)
      #	- do not touch these, except when /boot partition is selected_location:
      #	    - activate_changed (set to true)
      #	    - repl_mbr (set to true when we need to update existing GRUB, lilo MBRs,
      #			or when it looks like there is no code in the MBR at all,
      #			but NOT if this is a "Generic" (DOS) MBR, some unknown code
      #			or a Thinkpad MBR)
      #
      # always propose:
      #  - device_mapping (from "bios_id"s delivered by Storage, then let
      #                    devices with unknown "bios_id"s drop into the
      #                    gaps of this mapping or append at the end)
      #
      # if '/' and '/boot' were changed and selected_location is set and not
      # "custom", ask user with popup whether it is OK to change the
      # location and change it (with grub_DetectDisks() and grub_ConfigureLocation()
      # (see above))
      grub_LocationProposal

      # Note that the Propose() function is called every time before
      # Summary() is called.

      if BootCommon.sections == nil || Builtins.size(BootCommon.sections) == 0
        CreateSections()
        BootCommon.kernelCmdLine = Kernel.GetCmdLine
      else
        if Mode.autoinst
          # TODO whatever will be needed
          Builtins.y2debug("nothing to do in AI mode if sections exist")
        else
          BootCommon.FixSections(fun_ref(method(:CreateSections), "void ()"))
        end
      end
      if BootCommon.globals == nil || Builtins.size(BootCommon.globals) == 0
        BootCommon.globals = StandardGlobals()
      else
        if Mode.autoinst
          # TODO whatever will be needed
          Builtins.y2debug("nothing to do in AI mode if globals are defined")
        end
        # decided to merge in default values for missing keys, EVEN in AI mode (!)
        # this is primarily done to allow for the LocationProposal() to
        # run and set keys in globals before we check them for existing
        # keys here; but rather than checking for an empty globals map
        # before LocationProposal() and using the result here, we figured
        # that augmenting the globals is not such a bad idea even for the
        # AI case...
        Builtins.y2milestone("merging defaults to missing keys in globals")
        # Merge default globals where not yet set
        BootCommon.globals = Convert.convert(
          Builtins.union(StandardGlobals(), BootCommon.globals),
          :from => "map",
          :to   => "map <string, string>"
        )
        # this currently does nothing more than fixing the "default" key,
        # if that points to a section that does not exist anymore
        BootCommon.FixGlobals
      end

      # check if windows is on second disk and add remap if it is necessary
      # FATE #301994: Correct device mapping in case windows is installed on the second HD
      BootCommon.sections = checkWindowsSection(BootCommon.sections)

      BootCommon.UpdateProposalFromClient if Mode.installation

      BootCommon.isTrustedGrub
      Builtins.y2milestone("Proposed sections: %1", BootCommon.sections)
      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
    end

    # Save all bootloader configuration files to the cache of the PlugLib
    # PlugLib must be initialized properly !!!
    # @param [Boolean] clean boolean true if settings should be cleaned up (checking their
    #  correctness, supposing all files are on the disk
    # @param [Boolean] init boolean true to init the library
    # @param [Boolean] flush boolean true to flush settings to the disk
    # @return [Boolean] true if success
    def Save(clean, init, flush)
      # reduce device map to 8 devices
      # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
      ReduceDeviceMapTo8()

      # now really save the settings
      ret = BootCommon.Save(clean, init, flush)
      #importMetaData();

      ret
    end

    # FATE#303643 Enable one-click changes in bootloader proposal
    #
    #
    def urlLocationSummary
      Builtins.y2milestone("Prepare url summary for GRUB")
      locations = []
      line = "<ul>\n<li>"
      if BootCommon.globals["boot_mbr"] == "true"
        line << _(
          "Install bootcode into MBR (<a href=\"disable_boot_mbr\">do not install</a>)"
        )
      else
        line << _(
          "Do not install bootcode into MBR (<a href=\"enable_boot_mbr\">install</a>)"
        )
      end
      line << "</li>\n"
      locations << line

      line = "<li>"

      # check for separated boot partition, use root otherwise
      if BootStorage.BootPartitionDevice != BootStorage.RootPartitionDevice
        if BootCommon.globals["boot_boot"] == "true"
          line << _(
            "Install bootcode into /boot partition (<a href=\"disable_boot_boot\">do not install</a>)"
          )
        else
          line << _(
            "Do not install bootcode into /boot partition (<a href=\"enable_boot_boot\">install</a>)"
          )
        end
      else
        if BootCommon.globals["boot_root"] == "true"
          line << _(
            "Install bootcode into \"/\" partition (<a href=\"disable_boot_root\">do not install</a>)"
          )
        else
          line << _(
            "Do not install bootcode into \"/\" partition (<a href=\"enable_boot_root\">install</a>"
          )
        end
      end
      line << "</li></ul>"
      locations << line

      return _("Change Location: %s") % locations.join(" ")
    end

    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      ret = []
      lt = BootCommon.getLoaderType(false)
      ln = BootCommon.getLoaderName(lt, :summary)

      ret = [HTML.Colorize(ln, "red")] if lt == "none"

      # summary text, %1 is bootloader name (eg. LILO)
      ret = Builtins.add(ret, Builtins.sformat(_("Boot Loader Type: %1"), ln))

      # summary text, location is location description (eg. /dev/hda)
      locations = []
      line = ""


      if Ops.get(BootCommon.globals, "boot_boot", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootStorage.BootPartitionDevice, _(" (\"/boot\")"))
        )
      end
      if Ops.get(BootCommon.globals, "boot_extended", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootStorage.ExtendedPartitionDevice, _(" (extended)"))
        )
      end
      if Ops.get(BootCommon.globals, "boot_root", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootStorage.RootPartitionDevice, _(" (\"/\")"))
        )
      end
      if Ops.get(BootCommon.globals, "boot_mbr", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootCommon.mbrDisk, _(" (MBR)"))
        )
      end
      if Builtins.haskey(BootCommon.globals, "boot_custom")
        locations = Builtins.add(
          locations,
          Ops.get(BootCommon.globals, "boot_custom", "")
        )
      end
      if Ops.greater_than(Builtins.size(locations), 0)
        # FIXME: should we translate all devices to names and add MBR suffixes?
        ret = Builtins.add(
          ret,
          Builtins.sformat(
            _("Status Location: %1"),
            Builtins.mergestring(locations, ", ")
          )
        )
      end
      # it is necessary different summary for autoyast and installation
      # other mode than autoyast on running system
      if !Mode.config
        #ret = add(ret, _("Change Location:"));
        ret = Builtins.add(ret, urlLocationSummary)
      end

      # summary text. %1 is list of bootloader sections
      sects = []
      Builtins.foreach(BootCommon.sections) do |s|
        title = Ops.get_string(s, "name", "")
        # section name "suffix" for default section
        _def = title == Ops.get(BootCommon.globals, "default", "") ?
          _(" (default)") :
          ""
        sects = Builtins.add(
          sects,
          String.EscapeTags(Builtins.sformat("+ %1%2", title, _def))
        )
      end

      ret = Builtins.add(
        ret,
        Builtins.sformat(
          _("Sections:<br>%1"),
          Builtins.mergestring(sects, "<br>")
        )
      )

      if Builtins.size(locations) == 0
        # summary text
        ret = Builtins.add(
          ret,
          _("Do not install boot loader; just create configuration files")
        )
      end

      order_sum = BootCommon.DiskOrderSummary
      ret = Builtins.add(ret, order_sum) if order_sum != nil
      deep_copy(ret)
    end


    # Update read settings to new version of configuration files
    def Update
      # update device map would be done in bootloader_preupdate
      # run update device only if it was not called or if update device
      # failed in bootloader_preupdate
      BootCommon.UpdateDeviceMap if !@update_device_map_done

      # During update, for libata device name migration ("/dev/hda1" ->
      # "/dev/sda1") and somesuch, we need to re-read and parse the rest of the
      # configuration file contents after internally updating the device map in
      # perl-Bootloader. This way, the device names are consistent with the
      # partitioning information we have set up in perl-Bootloader with
      # SetDiskInfo(), and device names in other config files can be translated
      # to Unix device names (#328448, this hits sections that are not
      # (re-)created by yast-Bootloader or later by perl-Bootloader anyway).
      BootCommon.SetDeviceMap(BootStorage.device_mapping)
      Read(true, true)

      BootCommon.UpdateSections
      BootCommon.UpdateGlobals

      nil
    end


    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader
      if BootCommon.location_changed || BootCommon.InstallingToFloppy
        # bnc #461613 - Unable to boot after making changes to boot loader
        # bnc #357290 - module rewrites grub generic code when leaving with no changes, which may corrupt grub
        grub_updateMBR
        if BootCommon.InstallingToFloppy
          if !saveToFLoppyPopup
            Builtins.y2error("Preparing floppy disk failed.")
            ret = false
          end
        end

        grub_ret = BootCommon.InitializeBootloader
        grub_ret = false if grub_ret == nil

        Builtins.y2milestone("GRUB return value: %1", grub_ret)
        if BootCommon.InstallingToFloppy
          BootCommon.updateTimeoutPopupForFloppy(
            BootCommon.getLoaderName("grub", :summary)
          )
        end
        ret = ret && grub_ret
        ret = ret && BootCommon.PostUpdateMBR
      end
      ret
    end


    def Dialogs
      {
        "installation" => fun_ref(
          method(:i386InstallDetailsDialog),
          "symbol ()"
        ),
        "loader"       => fun_ref(method(:i386LoaderDetailsDialog), "symbol ()")
      }
    end

    # Boot passed section once on next reboot.
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def FlagOnetimeBoot(section)
      result = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "/usr/sbin/grubonce \"%1\"",
            BootCommon.Section2Index(section)
          )
        )
      )
      Builtins.y2milestone("grubonce returned %1", result)
      Ops.get_integer(result, "exit", -1) == 0
    end

    def grub_section_types
      ["image", "xen", "menu", "other"]
    end


    # Return map of provided functions
    # @return a map of functions (eg. $["write"::Write])
    def GetFunctions
      {
        "read"            => fun_ref(
          method(:Read),
          "boolean (boolean, boolean)"
        ),
        "reset"           => fun_ref(method(:Reset), "void (boolean)"),
        "propose"         => fun_ref(method(:Propose), "void ()"),
        "save"            => fun_ref(
          method(:Save),
          "boolean (boolean, boolean, boolean)"
        ),
        "summary"         => fun_ref(method(:Summary), "list <string> ()"),
        "update"          => fun_ref(method(:Update), "void ()"),
        "write"           => fun_ref(method(:Write), "boolean ()"),
        "widgets"         => fun_ref(
          method(:grubWidgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs"         => fun_ref(
          method(:Dialogs),
          "map <string, symbol ()> ()"
        ),
        "section_types"   => fun_ref(
          method(:grub_section_types),
          "list <string> ()"
        ),
        "flagonetimeboot" => fun_ref(
          method(:FlagOnetimeBoot),
          "boolean (string)"
        )
      }
    end

    # Initializer of GRUB bootloader
    def Initializer
      Builtins.y2milestone("Called GRUB initializer")
      BootCommon.current_bootloader_attribs = {
        "alias_keys"         => [],
        "propose"            => true,
        "read"               => true,
        "scratch"            => true,
        "additional_entries" => [
          Item(
            Id(:propose_deep),
            # menubutton item, keep as short as possible
            _("Propose and &Merge with Existing GRUB Menus")
          )
        ],
        "restore_mbr"        => true,
        "key_only_once"      => false,
        "bootloader_on_disk" => true
      }

      BootCommon.InitializeLibrary(false, "grub")

      nil
    end

    # Constructor
    def BootGRUB
      Ops.set(
        BootCommon.bootloader_attribs,
        "grub",
        {
          "required_packages" => ["grub"],
          "loader_name"       => "GRUB",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end


    # bnc#494630 GRUB configuration in installation workflow fail with more than 8 disks on software raid
    # Return all disks for checking in device map
    #
    # @param string boot disk
    # @return [Array<String>] disk devices

    def ReturnAllDisks(boot_disk)
      ret = []
      tm = Storage.GetTargetMap
      b_disk = Ops.get_map(tm, boot_disk, {})
      if Ops.get(b_disk, "type") == :CT_MD
        boot_partition = BootCommon.getBootPartition
        b_disk_partitions = Ops.get_list(b_disk, "partitions", [])
        Builtins.foreach(
          Convert.convert(
            b_disk_partitions,
            :from => "list",
            :to   => "list <map>"
          )
        ) do |p|
          if Ops.get_string(p, "device", "") == boot_partition
            if Ops.greater_than(
                Builtins.size(Ops.get_list(p, "devices", [])),
                0
              ) &&
                Ops.get(p, "type") == :sw_raid
              Builtins.foreach(Ops.get_list(p, "devices", [])) do |dev|
                p_dev = Storage.GetDiskPartition(dev)
                disk_dev = Ops.get_string(p_dev, "disk", "")
                if disk_dev != ""
                  ret = Builtins.add(ret, disk_dev)
                else
                  Builtins.y2error(
                    "Real disk was not found for device: %1",
                    dev
                  )
                end
              end
            else
              if Ops.get(p, "type") == :sw_raid
                Builtins.y2error(
                  "soft raid partition: %1 doesn't include any devices: %2",
                  boot_partition,
                  Ops.get_list(p, "devices", [])
                )
              else
                Builtins.y2error("Disk is not soft-raid %1", b_disk)
              end
              ret = Builtins.add(ret, boot_disk)
            end
          end
        end
      else
        Builtins.y2milestone("Boot disk is not on MD-RAID")
        ret = Builtins.add(ret, boot_disk)
      end
      Builtins.y2milestone(
        "Devices for checking if they are in device map: %1",
        ret
      )
      deep_copy(ret)
    end

    # bnc#494630 GRUB configuration in installation workflow fail with more than 8 disks on software raid
    # Function check if boot disk is in device map
    #
    # @return [Boolean] true if boot device is not in device map

    def CheckDeviceMap
      # FATE #303548 - Grub: limit device.map to devices detected by BIOS
      ret = false
      boot_disk = BootCommon.getBootDisk
      disks = ReturnAllDisks(boot_disk)
      Builtins.foreach(disks) do |disk|
        ret = ret ||
          checkBootDeviceInDeviceMap(disk, BootStorage.Dev2MountByDev(disk))
      end if Ops.greater_than(
        Builtins.size(disks),
        0
      )
      ret
    end

    publish :variable => :merge_level, :type => "symbol"
    publish :variable => :update_device_map_done, :type => "boolean"
    publish :variable => :disks_order, :type => "list <string>"
    publish :function => :grub_InstallingToFloppy, :type => "boolean ()"
    publish :function => :grub_updateMBR, :type => "boolean ()"
    publish :function => :ReduceDeviceMapTo8, :type => "boolean ()"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :variable => :grub_help_messages, :type => "map <string, string>"
    publish :variable => :grub_descriptions, :type => "map <string, string>"
    publish :function => :grubWidgets, :type => "map <string, map <string, any>> ()"
    publish :function => :CheckAdditionalKernels, :type => "list <map <string, string>> ()"
    publish :function => :CreateSections, :type => "void ()"
    publish :function => :StandardGlobals, :type => "map <string, string> ()"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :FlagOnetimeBoot, :type => "boolean (string)"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootGRUB, :type => "void ()"
    publish :function => :CheckDeviceMap, :type => "boolean ()"
  end

  BootGRUB = BootGRUBClass.new
  BootGRUB.main
end
