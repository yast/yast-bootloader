# encoding: utf-8

# File:
#      modules/BootELILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for ELILO configuration
#      and installation
#
# Authors:
#      Joachim Plack <jplack@suse.de>
#      Jiri Srain <jsrain@suse.cz>
#      Andreas Schwab <schwab@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class BootELILOClass < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "BootArch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Installation"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "String"
      Yast.import "Arch"

      Yast.include self, "bootloader/elilo/helps.rb"
      Yast.include self, "bootloader/routines/popups.rb"
      Yast.include self, "bootloader/elilo/dialogs.rb"



      # private variables

      # Name of EFI entry when read settings
      @old_efi_entry = nil

      # elilo.conf path
      @elilo_conf_filename = "/boot/efi/SuSE/elilo.conf"

      # True if EFI entry should be recreated
      @create_efi_entry = true

      @efi_vendor = "SuSE"

      # bnc #450682 - adding boot entry to EFI
      # true is label was added

      @added_label_to_efi = false

      # Is the /sys/firmware/efi directory available?
      @efi_available = true


      Yast.include self, "bootloader/elilo/widgets.rb"
      BootELILO()
    end

    # misc. functions

    # Return mountpoint of partition holding EFI data
    # @return mountpoint if partition holding EFI data
    def getEfiMountPoint
      mountpoint = "/"
      # FIXME: UGLY HACK because of testsuites
      mountpoints = {}
      if Mode.test
        mountpoints = { "/" => ["/dev/hda2"], "/boot" => ["/dev/hda1"] }
      else
        mountpoints = Storage.GetMountPoints
      end
      if Builtins.haskey(mountpoints, "/boot/efi")
        mountpoint = "/boot/efi"
      elsif Builtins.haskey(mountpoints, "/boot")
        mountpoint = "/boot"
      end
      Builtins.y2milestone("Mountpoint of EFI: %1", mountpoint)
      mountpoint
    end


    # Get directory containing elilo.conf relative to EFI partition's root
    # @return directory containing elilo.conf relative to EFI root
    def getEliloConfSubdir
      Builtins.sformat("/efi/%1", @efi_vendor)
    end


    # Get path of elilo.conf relative to EFI partition's root
    # @return [String] path of elilo.conf relative to EFI partition's root
    def getEliloConfSubpath
      Builtins.sformat("%1/elilo.conf", getEliloConfSubdir)
    end


    # Return path to elilo.conf file
    # @return [String] path to elilo.conf
    def getEliloConfFilename
      # FIXME config file name location should be read from Library
      #  and it should not be needed here!!!
      ret = Builtins.sformat(
        "%1/efi/%2/elilo.conf",
        getEfiMountPoint,
        @efi_vendor
      )
      Builtins.y2milestone("elilo.conf sould be located at %1", ret)
      ret
    end

    # wrapper function to adjust to new grub name sceme
    def CreateLinuxSection(title)
      section = BootCommon.CreateLinuxSection(title)

      # don't translate label bnc #151486
      Ops.set(section, "description", Ops.get_string(section, "name", ""))
      Ops.set(section, "name", title)

      deep_copy(section)
    end



    # Propose sections to bootloader menu
    # modifies internal structures
    def CreateSections
      linux = CreateLinuxSection("linux")
      failsafe = CreateLinuxSection("failsafe")

      # bnc#588609 - Problems writing elilo
      xen = {}
      xen = CreateLinuxSection("xen") if BootCommon.XenPresent

      # append for default section is in global
      # FIXME do it later
      #    if (haskey (linux, "append"))
      #  	linux = remove (linux, "append");
      if xen != nil && Ops.greater_than(Builtins.size(xen), 0)
        BootCommon.sections = [linux, failsafe, xen]
      else
        BootCommon.sections = [linux, failsafe]
      end

      nil
    end


    # Propose global options of bootloader
    # modifies internal structures
    def CreateGlobals
      BootCommon.globals = {
        # FIXME do it later
        #	"append" : BootArch::DefaultKernelParams (""),
        "default"     => "linux",
        "timeout"     => "8",
        "prompt"      => "true",
        # bnc #438276 - no 'read-only'
        "relocatable" => "true"
      }

      nil
    end


    # general functions


    # Export bootloader settings to a map
    # @return bootloader settings
    def Export
      ret = BootCommon.Export
      Ops.set(ret, "old_efi_entry", @old_efi_entry)
      Ops.set(ret, "elilo_conf_filename", @elilo_conf_filename)
      Ops.set(ret, "create_efi_entry", @create_efi_entry)
      deep_copy(ret)
    end


    # Import settings from a map
    # @param [Hash] settings map of bootloader settings
    def Import(settings)
      settings = deep_copy(settings)
      BootCommon.Import(settings)
      @old_efi_entry = Ops.get_string(settings, "old_efi_entry")
      @elilo_conf_filename = getEliloConfFilename
      @create_efi_entry = Ops.get_boolean(
        settings,
        "create_efi_entry",
        Ops.get_string(settings, "location", "") != ""
      )
      true
    end


    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      Yast.import "Product"
      efi_entry_found = false
      @elilo_conf_filename = getEliloConfFilename
      # copy old elilo.conf from /boot/<something> to /etc in case of upgrade
      # (if /etc/elilo.conf doesn't exist)
      if Ops.less_or_equal(SCR.Read(path(".target.size"), "/etc/elilo.conf"), 0) &&
          Ops.greater_than(
            SCR.Read(path(".target.size"), @elilo_conf_filename),
            0
          )
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/bin/cp %1 /etc/elilo.conf", @elilo_conf_filename)
        )
      end
      SCR.Execute(path(".target.bash"), "/bin/touch /etc/elilo.conf")
      BootCommon.DetectDisks
      ret = BootCommon.Read(reread, avoid_reading_device_map)

      # check for meaningless EFI entry name in sysconfig
      if !Builtins.haskey(BootCommon.globals, "boot_efilabel") ||
          Ops.get(BootCommon.globals, "boot_efilabel", "") == "mbr" ||
          Ops.get(BootCommon.globals, "boot_efilabel", "") == "" ||
          Ops.get(BootCommon.globals, "boot_efilabel", "") == nil
        efi_path = String.Replace(getEliloConfSubpath, "/", "\\")
        # Read Firmware setting from NVRam
        efi_status = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("/usr/sbin/efibootmgr |grep \"%1\"", efi_path)
          )
        )
        if Ops.get_integer(efi_status, "exit", 0) != 0
          Ops.set(BootCommon.globals, "boot_efilabel", Product.name)
        else
          output = Ops.get_string(efi_status, "stdout", "")
          lines = Builtins.splitstring(output, "\n")
          output = Ops.get_string(lines, 0, "")
          if Builtins.regexpmatch(output, 'Boot.*\* (.*)  HD')
            Ops.set(
              BootCommon.globals,
              "boot_efilabel",
              Builtins.regexpsub(output, 'Boot.*\* (.*)  HD', "\\1")
            )
            efi_entry_found = true
          else
            Ops.set(BootCommon.globals, "boot_efilabel", Product.name)
          end
        end
      else
        efi_entry_found = 0 ==
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "/usr/sbin/efibootmgr |grep \"%1\"",
              Ops.get(BootCommon.globals, "boot_efilabel", "")
            )
          )
      end
      @create_efi_entry = !efi_entry_found
      @old_efi_entry = efi_entry_found ?
        Ops.get(BootCommon.globals, "boot_efilabel", "") :
        nil
      ret
    end


    # Reset bootloader settings
    def Reset(init)
      return if Mode.autoinst
      @create_efi_entry = true
      BootCommon.Reset(init)

      nil
    end


    # Propose bootloader settings
    def Propose
      Yast.import "Product"
      if !BootCommon.was_proposed
        @create_efi_entry = true
        # make sure the code handling globals below triggers and that
        # boot_efilabel is recreated
        if Builtins.haskey(BootCommon.globals, "boot_efilabel")
          BootCommon.globals = Builtins.remove(
            BootCommon.globals,
            "boot_efilabel"
          )
        end
      end
      @create_efi_entry = true if !Stage.initial
      @create_efi_entry = false if Mode.update
      @efi_available = 0 ==
        Convert.to_integer(
          SCR.Execute(path(".target.bash"), "test -d /sys/firmware/efi")
        )
      @create_efi_entry = false if !@efi_available
      @elilo_conf_filename = getEliloConfFilename
      BootCommon.DetectDisks
      BootCommon.del_parts = BootStorage.getPartitionList(:deleted, "elilo")

      if BootCommon.sections == nil || Builtins.size(BootCommon.sections) == 0
        CreateSections()
        BootCommon.kernelCmdLine = Kernel.GetCmdLine
      else
        if Mode.autoinst
          Builtins.y2debug("Nothing to do for propose in AI mode")
        else
          BootCommon.FixSections(fun_ref(method(:CreateSections), "void ()"))
        end
      end

      if BootCommon.globals == nil || Builtins.size(BootCommon.globals) == 0
        CreateGlobals()
      end

      if Ops.get(BootCommon.globals, "boot_efilabel") == nil ||
          Ops.get(BootCommon.globals, "boot_efilabel") == ""
        Ops.set(BootCommon.globals, "boot_efilabel", Product.name)
      end

      BootCommon.UpdateProposalFromClient if Mode.installation

      Builtins.y2milestone(
        "EFI entry name: %1",
        Ops.get(BootCommon.globals, "boot_efilabel", "")
      )
      Builtins.y2milestone("Proposed sections: %1", BootCommon.sections)
      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
    end


    # Save all bootloader configuration files
    # @return [Boolean] true if success
    def Save(clean, init, flush)
      ret = BootCommon.Save(clean, init, flush)
      ret
    end


    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      # summary text, %1 is bootloader name (eg. LILO)
      result = [
        Builtins.sformat(
          _("Boot loader type: %1"),
          BootCommon.getLoaderName(BootCommon.getLoaderType(false), :summary)
        )
      ]

      if Ops.get(BootCommon.globals, "boot_efilabel", "") == "" ||
          !@create_efi_entry
        result =
          # summary text
          Builtins.add(result, _("Do Not Create EFI Boot Manager Entry"))
      else
        result = Builtins.add(
          result,
          Builtins.sformat(
            # summary text, %1 is label of the entry of EFI boot manager
            _("Create EFI Boot Manager Entry %1"),
            Ops.get(BootCommon.globals, "boot_efilabel", "")
          )
        )
      end
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
      # summary text. %1 is list of bootloader sections
      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Sections:<br>%1"),
          Builtins.mergestring(sects, "<br>")
        )
      )
      deep_copy(result)
    end


    # Update read settings to new version of configuration files
    def Update
      # Update global options of bootloader
      # modifies internal structures
      if Ops.get(BootCommon.globals, "timeout", "") == ""
        Ops.set(BootCommon.globals, "timeout", "8")
      end
      Ops.set(BootCommon.globals, "append", BootArch.DefaultKernelParams(""))

      BootCommon.UpdateSections 
      # FIXME EFI entry name

      nil
    end


    # Install the bootloader, display a popup with log if something
    #  goes wrong
    # @param [String] command string command to install the bootloader
    # @param [String] logfile string filename of file used to write bootloader log
    # @return [Boolean] true on success
    # FIXME get rid of this function
    def installBootLoader(command, logfile)
      Builtins.y2milestone("Running command %1", command)
      exit = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      ret = 0 == Ops.get_integer(exit, "exit", 1)
      if !ret
        Builtins.y2milestone(
          "Exit code of %1: %2",
          command,
          Ops.get_integer(exit, "exit", -1)
        )
        log = Convert.to_string(SCR.Read(path(".target.string"), logfile))
        log = Ops.add(
          Ops.add(log, Ops.get_string(exit, "stdout", "")),
          Ops.get_string(exit, "stderr", "")
        )
        if Ops.get_integer(exit, "exit", 1) == 139
          # means: process received signal SIGSEGV
          # please, use some usual translation
          # proofreaders: don't change this text
          log = Ops.add(log, _("Segmentation fault"))
        end

        errorWithLogPopup(
          Builtins.sformat(
            # error popup - label, %1 is bootloader name
            _("Error Occurred while Installing %1"),
            BootCommon.getLoaderName(BootCommon.getLoaderType(false), :summary)
          ),
          log
        )
      else
        @added_label_to_efi = true
        Builtins.y2milestone("Adding label to EFI finish successful")
      end
      ret
    end

    # bnc #438215 - YaST creates efibootloader entry twice
    # Function convert number of partition to hexa
    #
    # @param any number of boot partition (10 or "10")
    # @return [String] number boot partition in hexa ("a") - without "0x"
    def tomyhexa(boot_part)
      boot_part = deep_copy(boot_part)
      ret = "1000"

      int_boot_part = Builtins.tointeger(boot_part)
      if int_boot_part != nil
        hexa = Builtins.tohexstring(int_boot_part)
        if Builtins.search(hexa, "x") != nil
          hexa_without_0x = Builtins.splitstring(hexa, "x")
          if Ops.greater_than(Builtins.size(hexa_without_0x), 1)
            ret = Ops.get(hexa_without_0x, 1, "1000")
          end
        end
      end
      ret
    end


    # bnc #269198 change efi-label
    # Function check if there exist same efi-label or different for
    # same partition if efi-label is different delete it and create new one
    # if it is same nothing to do it.

    def updateEFILabel
      ret = true
      cmd = ""
      mp = Storage.GetMountPoints
      boot_dev = Ops.get_string(mp, [getEfiMountPoint, 0], "/boot/efi")
      splited = Storage.GetDiskPartition(boot_dev)
      boot_part = Ops.get_integer(splited, "nr", 0)
      boot_disk = Ops.get_string(splited, "disk", "")


      # command for checking same boot entry in efi bnc #438215 (YaST creates efibootloader entry twice)
      cmd = Builtins.sformat(
        "/usr/sbin/efibootmgr -v | grep -c \"%1.*HD(%2.*File(.\\efi.\\SuSE.\\elilo.efi)\"",
        Ops.get(BootCommon.globals, "boot_efilabel", ""),
        tomyhexa(boot_part)
      )

      # check how many entries with same label and partition is actually in efi
      Builtins.y2milestone("run command %1", cmd)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("output of command %1", out)

      # check number of same boot entries in efi
      # if boot entry is added -> don't add it again
      if Builtins.deletechars(Ops.get_string(out, "stdout", ""), "\n") != "0"
        if Ops.get_integer(out, "exit", 0) == 0
          Builtins.y2milestone("Skip adding new boot entry - EFI Label exist")
        else
          Builtins.y2error("Calling command %1 faild", cmd)
        end
        return ret
      else
        cmd = Builtins.sformat(
          "/usr/sbin/efibootmgr -v | grep -c \"HD(%1.*File(.\\efi.\\SuSE.\\elilo.efi)\"",
          tomyhexa(boot_part)
        )
        # check how many entries with same label and partition is actually in efi
        Builtins.y2milestone("run command %1", cmd)
        out2 = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
        Builtins.y2milestone("output of command %1", out2)

        # check how many boot entries have same number of partitions
        if Builtins.deletechars(Ops.get_string(out2, "stdout", ""), "\n") != "0"
          # delete old boot entry

          cmd = Builtins.sformat(
            "efibootmgr -v |grep \"HD(%1.*File(.\\efi.\\SuSE.\\elilo.efi)\" | cut -d \" \" -f 1",
            tomyhexa(boot_part)
          )
          Builtins.y2milestone("run command %1", cmd)
          out2 = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
          Builtins.y2milestone("output of command %1", out2)

          boot_entries = Ops.get_string(out2, "stdout", "")
          Builtins.y2milestone(
            "EFI boot entries with \"same\" boot partition %1",
            boot_entries
          )

          list_boot_entries = Builtins.splitstring(boot_entries, "\n")

          Builtins.y2milestone("list_boot_entries=%1", list_boot_entries)

          Builtins.foreach(list_boot_entries) do |entry|
            if Builtins.deletechars(entry, "\n*") != "" &&
                Builtins.deletechars(entry, "\n*") != nil
              cmd = Builtins.sformat(
                "/usr/sbin/efibootmgr --delete-bootnum --bootnum %1 -q;",
                Builtins.substring(Builtins.deletechars(entry, "\n*"), 4, 4)
              )
              Builtins.y2milestone("run command %1", cmd)
              out2 = Convert.to_map(
                SCR.Execute(path(".target.bash_output"), cmd)
              )
              Builtins.y2milestone("output of command %1", out2)
            end
          end
        end
        # add new boot entry
        bl_logfile = "/var/log/YaST2/y2log_bootloader"
        bl_command = Builtins.sformat(
          "/usr/sbin/efibootmgr -v --create --label \"%1\" " +
            "--disk %2 --part %3 " +
            "--loader '\\efi\\SuSE\\elilo.efi' --write-signature >> %4 2>&1",
          Ops.get(BootCommon.globals, "boot_efilabel", ""),
          boot_disk,
          boot_part,
          bl_logfile
        )
        ret = ret && installBootLoader(bl_command, bl_logfile)
      end
      ret
    end

    # FIXME: efibootmgr doesn't provide info about disk!
    # bnc #450682 - adding boot entry to EFI
    # function delete all existing boot entry with same name and partition number
    # @param [String] name of label
    # @param string number of partition

    def deleteSameEFIBootEntry(name, part_no)
      part_no = deep_copy(part_no)
      still_exist = true

      cmd = Builtins.sformat(
        "efibootmgr -v |grep \"%1.*HD(%2.*File(.\\efi.\\SuSE.\\elilo.efi)\" | cut -d \" \" -f 1",
        name,
        tomyhexa(part_no)
      )
      Builtins.y2milestone("run command %1", cmd)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone("output of command %1", out)

      boot_entries = Ops.get_string(out, "stdout", "")
      Builtins.y2milestone(
        "EFI boot entries with \"same\" boot partition %1",
        boot_entries
      )

      list_boot_entries = Builtins.splitstring(boot_entries, "\n")

      Builtins.y2milestone("list_boot_entries=%1", list_boot_entries)

      Builtins.foreach(list_boot_entries) do |entry|
        if Builtins.deletechars(entry, "\n*") != "" &&
            Builtins.deletechars(entry, "\n*") != nil
          cmd = Builtins.sformat(
            "/usr/sbin/efibootmgr --delete-bootnum --bootnum %1 -q;",
            Builtins.substring(Builtins.deletechars(entry, "\n*"), 4, 4)
          )
          Builtins.y2milestone("run command %1", cmd)
          out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
          Builtins.y2milestone("output of command %1", out)
        end
      end

      nil
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      Builtins.y2milestone("run Write function from BootELILO")
      #	SCR::Execute (.target.bash, "/sbin/elilo");
      ret = BootCommon.UpdateBootloader
      ret = false if ret == nil

      # FIXME find a better way to report status
      if ret && !@efi_available
        Popup.TimedMessage(
          _(
            "System was not booted via EFI firmware. To boot your\ncomputer, you need to load ELILO via the EFI shell."
          ),
          10
        )
      end

      updateEFILabel if Mode.normal

      if BootCommon.location_changed || @create_efi_entry
        mp = Storage.GetMountPoints
        boot_dev = Ops.get_string(mp, [getEfiMountPoint, 0], "/boot/efi")
        splited = Storage.GetDiskPartition(boot_dev)
        boot_part = Ops.get_integer(splited, "nr", 0)
        boot_disk = Ops.get_string(splited, "disk", "")
        Builtins.y2milestone("Disk: %1, Part: %2", boot_disk, boot_part)

        # Create new EFI Bootmgr Label if specified
        if Ops.get(BootCommon.globals, "boot_efilabel", "") != ""
          bl_logfile = "/var/log/YaST2/y2log_bootloader"
          bl_command = Builtins.sformat(
            "/usr/sbin/efibootmgr -v --create --label \"%1\" " +
              "--disk %2 --part %3 " +
              "--loader '\\efi\\SuSE\\elilo.efi' --write-signature >> %4 2>&1",
            Ops.get(BootCommon.globals, "boot_efilabel", ""),
            boot_disk,
            boot_part,
            bl_logfile
          )

          # command for checking same boot entry in efi bnc #438215 (YaST creates efibootloader entry twice)
          cmd = Builtins.sformat(
            "/usr/sbin/efibootmgr -v | grep -c \"%1.*HD(%2.*File(.\\efi.\\SuSE.\\elilo.efi)\"",
            Ops.get(BootCommon.globals, "boot_efilabel", ""),
            tomyhexa(boot_part)
          )
          Builtins.y2milestone("Command for checking same boot entry: %1", cmd)

          # check how many entries with same label and partition is actually in efi
          out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))

          # check number of same boot entries in efi
          # if boot entry is added -> don't add it again
          if Builtins.deletechars(Ops.get_string(out, "stdout", ""), "\n") == "0"
            ret = ret && installBootLoader(bl_command, bl_logfile)
          else
            if @added_label_to_efi
              Builtins.y2milestone(
                "Skip adding boot entry: %1 to EFI. There already exist and was added: %2 with \n\t\t\t\tsame label and partition.",
                Ops.get(BootCommon.globals, "boot_efilabel", ""),
                Builtins.deletechars(Ops.get_string(out, "stdout", ""), "\n")
              )
            else
              # delete efi entry with same label name and partition
              deleteSameEFIBootEntry(
                Ops.get(BootCommon.globals, "boot_efilabel", ""),
                boot_part
              )
              # add new efi boot entry
              ret = ret && installBootLoader(bl_command, bl_logfile)
            end
          end
        end


        # Remove existing old, obsolete menu entries
        #
        # FIXME should be handled completly through the library

        # Detect the current default boot entry (e.g. "0007")
        default_entry_map = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            "/usr/sbin/efibootmgr |grep ^BootOrder: | " +
              "cut -d ' ' -f 2 | cut -d ',' -f 1"
          )
        )
        new_entry = Ops.get_string(default_entry_map, "stdout", "")

        # Check for validity -- returned default_entry has to be 4 chars long
        # and be composed of numbers and characters only
        if Builtins.size(new_entry) != 4 &&
            Builtins.regexpmatch(new_entry, "[0-9A-F]") == false
          Builtins.y2error(
            "BootELILO: Found default boot entry %1 isn't valid",
            new_entry
          )
        else
          # Remove newlines and carriage returns in string
          new_entry = Builtins.deletechars(new_entry, "\n ")

          # Attach prefix "Boot" for proper matching
          new_entry = Ops.add("Boot", new_entry)

          # Prepare command for fetching string "HD(...)"
          # from efibootmgr output
          command = Builtins.sformat(
            "set -o pipefail; /usr/sbin/efibootmgr -v | " +
              "grep '%1' |sed 's/%1.*\\(HD(.*)File(.*)\\).*/\\1/'",
            String.Quote(new_entry)
          )

          hd_descr_map = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )
          Builtins.y2milestone("BootELILO: hd_descr_map = %1", hd_descr_map)

          # Remove newlines and carriage returns in string
          hd_descr = Builtins.deletechars(
            Ops.get_string(hd_descr_map, "stdout", ""),
            "\n "
          )

          # Prepare command for fetching boot entry number corresponding
          # to "HD(...)" string from efibootmgr output
          command = Builtins.sformat(
            "set -o pipefail; /usr/sbin/efibootmgr -v |" +
              "grep '%1' |awk '{print $1}'",
            String.Quote(hd_descr)
          )

          entries2remove_map = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )
          Builtins.y2milestone(
            "BootELILO: entries2remove_map = %1",
            entries2remove_map
          )
          entries2remove_string = Ops.get_string(
            entries2remove_map,
            "stdout",
            ""
          )

          # Convert the string containing the entries to be removed to a list
          entries2remove_list = Builtins.splitstring(
            entries2remove_string,
            "\n"
          )

          # Check if there are entries to remove, thus if listsize is greater than 0
          listsize = Builtins.size(entries2remove_list)
          if Ops.greater_than(listsize, 0)
            # Rermove the last entry of the list (because it's an empty one)
            lastentry = Ops.subtract(listsize, 1)
            entries2remove_list = Builtins.remove(
              entries2remove_list,
              lastentry
            )
            Builtins.y2milestone(
              "BootELILO: entries2remove_list = %1",
              entries2remove_list
            )

            # Filter the bootnumbers from strings for further usage
            entries2remove_list = Builtins.maplist(entries2remove_list) do |entry2remove|
              if Builtins.issubstring(entry2remove, new_entry) == false
                entry2remove = Builtins.substring(entry2remove, 4, 4)
                next entry2remove
              end
            end

            # Delete obsolete bootentries by bootnumbers
            Builtins.foreach(entries2remove_list) do |entry2remove|
              command2 = Builtins.sformat(
                "/usr/sbin/efibootmgr --delete-bootnum --bootnum %1 -q;",
                entry2remove
              )
              Builtins.y2milestone("Running command %1", command2)
              ret_map = Convert.to_map(
                SCR.Execute(path(".target.bash_output"), command2)
              )
              Builtins.y2milestone("BootELILO: ret_map = %1", ret_map)
              ret = Ops.get_integer(ret_map, "exit", 1) == 0
            end
          else
            Builtins.y2milestone("BootELILO: No obsolete entry to remove")
          end
        end
      end
      ret
    end


    def Dialogs
      { "loader" => fun_ref(method(:EliloLoaderDetailsDialog), "symbol ()") }
    end

    # Set section to boot on next reboot.
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def FlagBootDefaultOnce(section)
      # For now a dummy
      true
    end

    def elilo_section_types
      ["image", "xen"]
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write"::Write])
    def GetFunctions
      {
        "export"              => fun_ref(method(:Export), "map ()"),
        "import"              => fun_ref(method(:Import), "boolean (map)"),
        "read"                => fun_ref(
          method(:Read),
          "boolean (boolean, boolean)"
        ),
        "reset"               => fun_ref(method(:Reset), "void (boolean)"),
        "propose"             => fun_ref(method(:Propose), "void ()"),
        "save"                => fun_ref(
          method(:Save),
          "boolean (boolean, boolean, boolean)"
        ),
        "summary"             => fun_ref(method(:Summary), "list <string> ()"),
        "update"              => fun_ref(method(:Update), "void ()"),
        "write"               => fun_ref(method(:Write), "boolean ()"),
        "widgets"             => fun_ref(
          method(:Widgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs"             => fun_ref(
          method(:Dialogs),
          "map <string, symbol ()> ()"
        ),
        "section_types"       => fun_ref(
          method(:elilo_section_types),
          "list <string> ()"
        ),
        "flagbootdefaultonce" => fun_ref(
          method(:FlagBootDefaultOnce),
          "boolean (string)"
        )
      }
    end

    # Initializer of ELILO bootloader
    def Initializer
      Builtins.y2milestone("Called ELILO initializer")
      BootCommon.current_bootloader_attribs = {
        "propose"            => true,
        "read"               => true,
        "scratch"            => true,
        "restore_mbr"        => true,
        "bootloader_on_disk" => true
      }

      BootCommon.InitializeLibrary(false, "elilo")

      nil
    end

    # Constructor
    def BootELILO
      Ops.set(
        BootCommon.bootloader_attribs,
        "elilo",
        {
          "required_packages" => ["elilo", "efibootmgr"],
          "loader_name"       => "ELILO",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :variable => :elilo_help_messages, :type => "map <string, string>"
    publish :variable => :elilo_descriptions, :type => "map <string, string>"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :variable => :old_efi_entry, :type => "string"
    publish :variable => :elilo_conf_filename, :type => "string"
    publish :variable => :create_efi_entry, :type => "boolean"
    publish :variable => :added_label_to_efi, :type => "boolean"
    publish :function => :getTargetWidget, :type => "term ()"
    publish :function => :targetInit, :type => "void (string)"
    publish :function => :targetHandle, :type => "symbol (string, map)"
    publish :function => :targetStore, :type => "void (string, map)"
    publish :function => :targetValidate, :type => "boolean (string, map)"
    publish :function => :getEfiMountPoint, :type => "string ()"
    publish :function => :getEliloConfSubdir, :type => "string ()"
    publish :function => :getEliloConfSubpath, :type => "string ()"
    publish :function => :getEliloConfFilename, :type => "string ()"
    publish :function => :CreateSections, :type => "void ()"
    publish :function => :CreateGlobals, :type => "void ()"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :FlagBootDefaultOnce, :type => "boolean (string)"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootELILO, :type => "void ()"
  end

  BootELILO = BootELILOClass.new
  BootELILO.main
end
