# encoding: utf-8

# File:
#      modules/BootZIPL.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for ZIPL configuration
#      and installation
#
# Authors:
#      Joachim Plack <jplack@suse.de>
#      Jiri Srain <jsrain@suse.cz>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class BootZIPLClass < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "BootArch"
      Yast.import "BootCommon"
      Yast.import "Installation"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Stage"

      Yast.include self, "bootloader/zipl/helps.rb"
      Yast.include self, "bootloader/routines/popups.rb"


      # local data
      @hw_descr = {
        "ctc"  => {
          "skeleton" => "hwcfg-ctc",
          "target"   => "ctc-bus-ccw-%1",
          "options"  => { "CCW_CHAN_IDS" => "%1 %2", "CCW_CHAN_MODE" => "%3" }
        },
        "qeth" => {
          "skeleton" => "hwcfg-qeth",
          "target"   => "qeth-bus-ccw-%1",
          "options"  => {
            "CCW_CHAN_IDS"  => "%1 %2 %3",
            "CCW_CHAN_MODE" => "%4"
          }
        },
        "iucv" => { "skeleton" => "hwcfg-iucv", "target" => "iucv-id-%1" }
      }
      BootZIPL()
    end

    # misc. functions

    # Update /etc/sysconfig/hardware configuration
    # Use data from install.inf file
    # @return [Boolean] true on success
    def updateHardwareConfig
      return true if !Stage.initial || Mode.update

      failed = false
      cfg = Convert.to_string(SCR.Read(path(".etc.install_inf.Hardware")))
      Builtins.y2milestone(
        "Read hardware configuration from install.inf: %1",
        cfg
      )
      l = Builtins.splitstring(cfg, ";")
      Builtins.foreach(l) do |s|
        args = Builtins.splitstring(s, ",")
        args = Builtins.maplist(args) do |a|
          while a != "" && Builtins.substring(a, 0, 1) == " "
            a = Builtins.substring(a, 1)
          end
          while a != "" &&
              Builtins.substring(a, Ops.subtract(Builtins.size(a), 1), 1) == " "
            a = Builtins.substring(a, 0, Ops.subtract(Builtins.size(a), 1))
          end
          a
        end
        key = Ops.get(args, 0, "")
        a1 = Ops.get(args, 1, "")
        a2 = Ops.get(args, 2, "")
        a3 = Ops.get(args, 3, "")
        a4 = Ops.get(args, 4, "")
        if key != ""
          descr = Ops.get(@hw_descr, key, {})
          src = Ops.get_string(descr, "skeleton", "")
          dst = Builtins.sformat(
            Ops.get_string(descr, "target", ""),
            a1,
            a2,
            a3,
            a4
          )
          Builtins.y2milestone("Template: %1, Target: %2", src, dst)
          command = Builtins.sformat(
            "/bin/cp /etc/sysconfig/hardware/skel/%1 /etc/sysconfig/hardware/hwcfg-%2",
            src,
            dst
          )
          if 0 != SCR.Execute(path(".target.bash"), command)
            Report.Error(
              # error report
              _("Copying hardware configuration template failed.")
            )
            failed = true
          end
          p = Builtins.add(path(".sysconfig.hardware.value"), dst)
          Builtins.foreach(Ops.get_map(descr, "options", {})) do |k, v|
            op = Builtins.add(p, k)
            v = Builtins.sformat(v, a1, a2, a3, a4)
            failed = true if !SCR.Write(op, v)
          end
        end
      end
      failed = true if !SCR.Write(path(".sysconfig.hardware"), nil)
      failed
    end


    # general functions

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "zipl")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      BootCommon.DetectDisks
      ret = BootCommon.Read(false, avoid_reading_device_map)
      ret
    end



    # wrapper function to adjust to special zipl needs
    def CreateLinuxSection(title)
      section = BootCommon.CreateLinuxSection(title)
      Ops.set(section, "target", "/boot/zipl")

      deep_copy(section)
    end




    # Propose bootloader settings
    def Propose
      BootCommon.DetectDisks
      parameters = BootArch.DefaultKernelParams("")

      BootCommon.globals = { "default" => "menu" }

      BootCommon.sections = [
        {
          "name"    => "menu",
          "default" => "1",
          "prompt"  => "true",
          "target"  => "/boot/zipl",
          "timeout" => "10",
          "list"    => Ops.add(
            Ops.add(BootCommon.translateSectionTitle("ipl"), ","),
            BootCommon.translateSectionTitle("failsafe")
          ),
          "type"    => "menu"
        },
        CreateLinuxSection("ipl"),
        CreateLinuxSection("failsafe")
      ]

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
      ret = BootCommon.Save(clean, init, flush)

      return ret if Mode.normal

      updateHardwareConfig
      ret
    end


    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      # summary
      [_("Install S390 Boot Loader")]
    end


    # Update read settings to new version of configuration files
    def Update
      Builtins.y2milestone("No update functionality implemented")

      nil
    end


    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader
      ret = ret && BootCommon.InitializeBootloader
      ret = false if ret == nil
      ret
    end


    def Dialogs
      {}
    end

    # Set section to boot on next reboot.
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def FlagOnetimeBoot(section)
      # For now a dummy
      true
    end

    def zipl_section_types
      ["image", "menu", "dump"]
    end

    def ziplWidgets
      {}
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write"::Write])
    def GetFunctions
      {
        #"export"		: Export,
        #"import"		: Import,
        "read"            => fun_ref(
          method(:Read),
          "boolean (boolean, boolean)"
        ),
        #"reset"		: Reset,
        "propose"         => fun_ref(
          method(:Propose),
          "void ()"
        ),
        "save"            => fun_ref(
          method(:Save),
          "boolean (boolean, boolean, boolean)"
        ),
        "summary"         => fun_ref(method(:Summary), "list <string> ()"),
        "update"          => fun_ref(method(:Update), "void ()"),
        "write"           => fun_ref(method(:Write), "boolean ()"),
        "widgets"         => fun_ref(
          method(:ziplWidgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs"         => fun_ref(
          method(:Dialogs),
          "map <string, symbol ()> ()"
        ),
        "section_types"   => fun_ref(
          method(:zipl_section_types),
          "list <string> ()"
        ),
        "flagonetimeboot" => fun_ref(
          method(:FlagOnetimeBoot),
          "boolean (string)"
        )
      }
    end

    # Initializer of S390 bootloader
    def Initializer
      Builtins.y2milestone("Called ZIPL initializer")
      BootCommon.current_bootloader_attribs = {
        "section_title" => "label",
        "propose"       => true,
        "read"          => true,
        "scratch"       => true
      }

      BootCommon.InitializeLibrary(false, "zipl")

      nil
    end

    # Constructor
    def BootZIPL
      Ops.set(
        BootCommon.bootloader_attribs,
        "zipl",
        {
          "loader_name"       => "zipl",
          "required_packages" => ["s390-tools"],
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :variable => :zipl_help_messages, :type => "map <string, string>"
    publish :variable => :zipl_descriptions, :type => "map <string, string>"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :updateHardwareConfig, :type => "boolean ()"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :FlagOnetimeBoot, :type => "boolean (string)"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootZIPL, :type => "void ()"
  end

  BootZIPL = BootZIPLClass.new
  BootZIPL.main
end
