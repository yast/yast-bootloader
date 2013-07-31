# encoding: utf-8

# File:
#      modules/BootLILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for LILO configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class BootLILOClass < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Pkg"
      Yast.import "String"
      Yast.import "Storage"
      Yast.import "Stage"


      Yast.include self, "bootloader/routines/popups.rb"
      BootLILO()
    end

    # remove blanks from section name and replace them with _
    # @param [String] original string
    # @return [String] fixed string
    def removeBlanks(original)
      # do not allow empty labels
      while Ops.greater_than(Builtins.size(original), 1) &&
          Builtins.substring(original, 0, 1) == " "
        original = Builtins.substring(original, 1)
      end
      while Ops.greater_than(Builtins.size(original), 1) &&
          Builtins.substring(
            original,
            Ops.subtract(Builtins.size(original), 1),
            1
          ) == " "
        original = Builtins.substring(
          original,
          0,
          Ops.subtract(Builtins.size(original), 1)
        )
      end
      if Ops.greater_than(Builtins.size(original), 15)
        original = Builtins.substring(original, 0, 15)
      end
      String.Replace(original, " ", "_")
    end


    # Propose sections to bootloader menu
    # modifies internal sreuctures
    def CreateSections
      out = [BootCommon.CreateLinuxSection("linux")]
      others = Storage.GetForeignPrimary
      if others != nil && Ops.greater_than(Builtins.size(others), 0)
        Builtins.foreach(others) do |o|
          parts = Builtins.splitstring(o, " ")
          while Ops.get(parts, 0, " ") == ""
            parts = Builtins.remove(parts, 0)
          end
          dev = Ops.get(parts, 0, "")
          parts = Builtins.remove(parts, 0)
          label = Builtins.mergestring(parts, " ")
          # don't add rewritten location (#19990)
          if dev != "" && label != "" && dev != BootCommon.loader_device &&
              (BootCommon.AddFirmwareToBootloader(BootCommon.mbrDisk) ||
                label != "Vendor diagnostics")
            m = {
              "name"          => BootCommon.translateSectionTitle(
                removeBlanks(label)
              ),
              "original_name" => label,
              "type"          => "chainloader",
              "chainloader"   => dev,
              "__auto"        => true,
              "__changed"     => true,
              "__devs"        => [dev]
            }
            out = Builtins.add(out, m)
          end
        end
      end
      out = Builtins.add(out, BootCommon.CreateLinuxSection("failsafe"))
      out = Builtins.add(out, BootCommon.CreateLinuxSection("memtest86"))
      out = Builtins.filter(out) { |s| s != {} && s != nil }
      BootCommon.sections = deep_copy(out)

      nil
    end

    # Propose global options of bootloader
    # modifies internal structures
    def CreateGlobals
      BootCommon.globals = {
        "default" => Ops.get_string(BootCommon.sections, [0, "name"], ""),
        "timeout" => "8",
        "gfxmenu" => "/boot/message",
        "prompt"  => "1"
      }

      nil
    end

    # general functions

    # Propose bootloader settings
    def Propose
      Builtins.y2debug(
        "Started propose: Glob: %1, Sec: %2",
        BootCommon.globals,
        BootCommon.sections
      )
      BootCommon.i386LocationProposal

      if BootCommon.sections == nil || Builtins.size(BootCommon.sections) == 0
        CreateSections()
        BootCommon.kernelCmdLine = Kernel.GetCmdLine
      else
        if Mode.autoinst
          # TODO whatever will be needed
          Builtins.y2debug("nothing to to in AI mode if sections exist")
        else
          BootCommon.FixSections(fun_ref(method(:CreateSections), "void ()"))
        end
      end
      if BootCommon.globals == nil || Builtins.size(BootCommon.globals) == 0
        CreateGlobals()
      else
        if Mode.autoinst
          # TODO whatever will be needed
          Builtins.y2debug("nothing to to in AI mode if globals are defined")
        else
          BootCommon.FixGlobals
        end
      end

      Builtins.y2milestone("Proposed sections: %1", BootCommon.sections)
      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
    end

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "lilo")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      BootCommon.DetectDisks
      ret = BootCommon.Read(false, avoid_reading_device_map)
      BootCommon.loader_device = Ops.get(BootCommon.globals, "stage1_dev", "")
      ret
    end

    # Save all bootloader configuration files to the cache of the PlugLib
    # PlugLib must be initialized properly !!!
    # @param [Boolean] clean boolean true if settings should be cleaned up (checking their
    #  correctness, supposing all files are on the disk
    # @param [Boolean] init boolean true to init the library
    # @param [Boolean] flush boolean true to flush settings to the disk
    # @return [Boolean] true if success
    def Save(clean, init, flush)
      Ops.set(BootCommon.globals, "stage1_dev", BootCommon.loader_device)
      ret = BootCommon.Save(clean, init, flush)
      ret
    end


    # Update read settings to new version of configuration files
    def Update
      BootCommon.UpdateDeviceMap

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
      BootCommon.loader_device = BootCommon.UpdateDevice(
        BootCommon.loader_device
      )

      nil
    end


    # If device is part of RAID (md), then return first of its members
    # otherwise return the same as argument
    # @param [String] device string device of the RAID
    # @return [String] first member of the RAID
    def getDeviceOfRaid(device)
      # get list of all partitions (not marked to be deleted)
      tm = Storage.GetTargetMap
      partitions = []

      Builtins.foreach(tm) do |dev, disk|
        if Storage.IsRealDisk(disk)
          l = Builtins.filter(Ops.get_list(disk, "partitions", [])) do |p|
            Ops.get_boolean(p, "delete", false) == false
          end
          partitions = Convert.convert(
            Builtins.merge(partitions, l),
            :from => "list",
            :to   => "list <map>"
          )
        end
      end

      # filter partitions to relevant list according to raid name
      md_list = Builtins.filter(partitions) do |e|
        Ops.get_string(e, "used_by_device", "") == device
      end
      # get the devices
      dev_list = Builtins.maplist(md_list) do |e|
        Ops.get_string(e, "device", "")
      end
      dev_list = Builtins.filter(dev_list) { |d| d != "" }
      if Ops.greater_than(Builtins.size(dev_list), 0)
        dev_list = Builtins.sort(dev_list)
        return Ops.get(dev_list, 0, "")
      end
      device
    end


    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader
      BootCommon.updateMBR
      if BootCommon.InstallingToFloppy
        if !saveToFLoppyPopup
          Builtins.y2error("Preparing floppy disk failed.")
          ret = false
        end
      end

      # Should we create a backup copy of bootloader bootsector?
      if Stage.initial
        mp = Storage.GetMountPoints
        data = Ops.get_list(mp, "/boot", Ops.get_list(mp, "/", []))
        bpd = Ops.get_string(data, 0, "")
        # ???? FIXME ???? how about LVM/MD ????
        if bpd == BootStorage.BootPartitionDevice &&
            getDeviceOfRaid(BootStorage.BootPartitionDevice) !=
              BootStorage.BootPartitionDevice &&
            Builtins.contains(
              BootStorage.getPartitionList(:boot, "lilo"),
              BootStorage.BootPartitionDevice
            )
          Builtins.y2milestone("Creating backup copy to bootsector")
          SCR.Execute(
            path(".target.bash"),
            Builtins.sformat(
              "/sbin/lilo -b %1",
              BootStorage.BootPartitionDevice
            )
          )
        end
      end

      ret = ret && BootCommon.InitializeBootloader
      ret = false if ret == nil
      ret = ret && BootCommon.PostUpdateMBR
      ret
    end

    def Dialogs
      {}
    end

    # Set section to boot on next reboot
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def FlagOnetimeBoot(section)
      result = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("/sbin/lilo -R \"%1\"", section)
        )
      )
      Builtins.y2milestone("lilo returned %1", result)
      Ops.get_integer(result, "exit", -1) == 0
    end


    def lilo_section_types
      ["image", "other"]
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write":BootLILO::Write])
    def GetFunctions
      {
        "dialogs"         => fun_ref(
          method(:Dialogs),
          "map <string, symbol ()> ()"
        ),
        "read"            => fun_ref(
          method(:Read),
          "boolean (boolean, boolean)"
        ),
        "propose"         => fun_ref(method(:Propose), "void ()"),
        "save"            => fun_ref(
          method(:Save),
          "boolean (boolean, boolean, boolean)"
        ),
        "summary"         => fun_ref(
          BootCommon.method(:i386Summary),
          "list <string> ()"
        ),
        "update"          => fun_ref(method(:Update), "void ()"),
        "write"           => fun_ref(method(:Write), "boolean ()"),
        "flagonetimeboot" => fun_ref(
          method(:FlagOnetimeBoot),
          "boolean (string)"
        ),
        "widgets"         => {}, # is not supported now
        "section_types"   => fun_ref(
          method(:lilo_section_types),
          "list <string> ()"
        )
      }
    end

    # Initializer of LILO bootloader
    def Initializer
      Builtins.y2milestone("Called LILO initializer")
      BootCommon.current_bootloader_attribs = {
        "propose"            => true,
        "read"               => true,
        "scratch"            => true,
        "restore_mbr"        => true,
        "bootloader_on_disk" => true
      }

      nil
    end

    # Constructor
    def BootLILO
      Ops.set(
        BootCommon.bootloader_attribs,
        "lilo",
        {
          "required_packages" => ["lilo"],
          "loader_name"       => "LILO",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :CreateSections, :type => "void ()"
    publish :function => :CreateGlobals, :type => "void ()"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :FlagOnetimeBoot, :type => "boolean (string)"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootLILO, :type => "void ()"
  end

  BootLILO = BootLILOClass.new
  BootLILO.main
end
