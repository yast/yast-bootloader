# encoding: utf-8

# File:
#      modules/BootGRUB2.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB2 configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id: BootGRUB.ycp 63508 2011-03-04 12:53:27Z jreidinger $
#
require "yast"
require "bootloader/grub2base"
require "bootloader/mbr_update"
require "bootloader/device_map_dialog"

module Yast
  import "Arch"
  import "Storage"
  import "BootCommon"
  import "HTML"

  class BootGRUB2Class < GRUB2Base
    def main
      super

      textdomain "bootloader"

      # includes
      # for shared some routines with grub
      Yast.include self, "bootloader/grub2/misc.rb"
      BootGRUB2()
    end

    # general functions

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "grub2")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      # TODO: check if necessary for grub2
      grub_DetectDisks
      ret = BootCommon.Read(false, avoid_reading_device_map)

      # TODO: check if necessary for grub2
      # refresh device map if not read
      if BootStorage.device_mapping == nil ||
          Builtins.size(BootStorage.device_mapping) == 0
        BootStorage.ProposeDeviceMap
      end

      if Mode.normal
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

      @orig_globals ||= deep_copy(BootCommon.globals)
      ret
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader

      if @orig_globals
        location = ["boot_mbr", "boot_boot", "boot_root", "boot_extended", "boot_custom", "boot_custom", "activate", "generic_mbr"]
        location.each do |i|
           BootCommon.location_changed = true if @orig_globals[i] != BootCommon.globals[i]
        end
      else
        # there is no original, so we do not read config, but propose it
        BootCommon.location_changed = true
      end

      if BootCommon.location_changed
        # bnc #461613 - Unable to boot after making changes to boot loader
        # bnc #357290 - module rewrites grub generic code when leaving with no changes, which may corrupt grub
        ::Bootloader::MBRUpdate.new.run

        grub_ret = BootCommon.InitializeBootloader
        grub_ret = false if grub_ret == nil

        Builtins.y2milestone("GRUB return value: %1", grub_ret)
        ret = ret && grub_ret
        ret = ret && BootCommon.PostUpdateMBR
      end

      # something with PMBR needed
      if BootCommon.pmbr_action
        boot_devices = BootCommon.GetBootloaderDevices
        boot_discs = boot_devices.map {|d| Storage.GetDisk(Storage.GetTargetMap, d)}
        boot_discs.uniq!
        gpt_disks = boot_discs.select {|d| d["label"] == "gpt" }
        gpt_disks_devices = gpt_disks.map {|d| d["device"] }

        pmbr_setup(BootCommon.pmbr_action, *gpt_disks_devices)
      end

      ret
    end

    def Propose
      super

      # do not repropose, only in autoinst mode to allow propose missing parts
      if !BootCommon.was_proposed || Mode.autoinst || Mode.autoupgrade
        case Arch.architecture
        when "i386", "x86_64"
          grub_LocationProposal
          # pass vga if available (bnc#896300)
          if !Kernel.GetVgaType.empty?
            BootCommon.globals["vgamode"]= Kernel.GetVgaType
          end
        when /ppc/
          partition = prep_partitions.first
          if partition
            BootCommon.globals["boot_custom"] = partition
          else
            # handle diskless setup, in such case do not write boot code anywhere (bnc#874466)
            # we need to detect what is mount on /boot and if it is nfs, then just
            # skip this proposal. In other case if it is not nfs, then it is error and raise exception
            BootCommon.DetectDisks
            if BootCommon.getBootDisk == "/dev/nfs"
              return
            else
              raise "there is no prep partition"
            end
          end
        when /s390/
          Builtins.y2milestone "no partition needed for grub2 on s390"
        else
          raise "unsuported architecture #{Arch.architecture}"
        end
      end
    end

    def prep_partitions
      target_map = Storage.GetTargetMap

      partitions = target_map.reduce([]) do |parts, pair|
        parts.concat(pair[1]["partitions"] || [])
      end

      prep_partitions = partitions.select do |partition|
        [0x41, 0x108].include? partition["fsid"]
      end

      y2milestone "detected prep partitions #{prep_partitions.inspect}"
      prep_partitions.map { |p| p["device"] }
    end

    # FATE#303643 Enable one-click changes in bootloader proposal
    #
    #
    def urlLocationSummary
      Builtins.y2milestone("Prepare url summary for GRUB2")
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

      # do not allow to switch on boot from partition that do not support it
      if BootStorage.can_boot_from_partition
        line << "<li>"

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
              "Do not install bootcode into \"/\" partition (<a href=\"enable_boot_root\">install</a>)"
            )
          end
        end
        line << "</li>"
      end

      if ["boot_root", "boot_boot", "boot_mbr", "boot_extended"].none? { |loc| BootCommon.globals[loc] == "true" }
          # no location chosen, so warn user that it is problem unless he is sure
          msg = _("Warning: No location for bootloader stage1 selected." \
            "Unless you know what you are doing please select above location.")
          line << "<li>" << HTML.Colorize(msg, "red") << "</li>"
      end

      line << "</ul>"

      # TRANSLATORS: title for list of location proposals
      return _("Change Location: %s") % line
    end


    # Display bootloader summary
    # @return a list of summary lines

    def Summary
      result = [
        Builtins.sformat(
          _("Boot Loader Type: %1"),
          BootCommon.getLoaderName(BootCommon.getLoaderType(false), :summary)
        )
      ]
      locations = []

      if BootCommon.globals["boot_boot"] == "true"
        locations << BootStorage.BootPartitionDevice + " (\"/boot\")"
      end
      if BootCommon.globals["boot_extended"] == "true"
        # TRANSLATORS: extended is here for extended partition. Keep translation short.
        locations << BootStorage.ExtendedPartitionDevice + _(" (extended)")
      end
      if BootCommon.globals["boot_root"] == "true"
        locations << BootStorage.RootPartitionDevice + " (\"/\")"
      end
      if BootCommon.globals["boot_mbr"] == "true"
        # TRANSLATORS: MBR is acronym for Master Boot Record, if nothing locally specific
        # is used in your language, then keep it as it is.
        locations << BootCommon.mbrDisk + _(" (MBR)")
      end
      if BootCommon.globals["boot_custom"] && !BootCommon.globals["boot_custom"].empty?
        locations << BootCommon.globals["boot_custom"]
      end
      if !locations.empty?
        result << Builtins.sformat(
            _("Status Location: %1"),
            locations.join(", ")
          )
      end

      # it is necessary different summary for autoyast and installation
      # other mode than autoyast on running system
      # both ppc and s390 have special devices for stage1 so it do not make sense
      # allow change of location to MBR or boot partition (bnc#879107)
      if !Arch.ppc && !Arch.s390 && !Mode.config
        result << urlLocationSummary
      end

      order_sum = BootCommon.DiskOrderSummary
      result << order_sum if order_sum

      return result
    end

    def Dialogs
      Builtins.y2milestone("Called GRUB2 Dialogs")
      {
        "installation" => fun_ref(
          ::Bootloader::DeviceMapDialog.method(:run),
          "symbol ()"
        ),
        "loader"       => fun_ref(
          method(:Grub2LoaderDetailsDialog),
          "symbol ()"
        )
      }
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write":BootGRUB2::Write])
    def GetFunctions
      {
        "read"    => fun_ref(method(:Read), "boolean (boolean, boolean)"),
        "reset"   => fun_ref(method(:Reset), "void (boolean)"),
        "propose" => fun_ref(method(:Propose), "void ()"),
        "save"    => fun_ref(method(:Save), "boolean (boolean, boolean, boolean)"),
        "summary" => fun_ref(method(:Summary), "list <string> ()"),
        "update"  => fun_ref(method(:Update), "void ()"),
        "widgets" => fun_ref(
          method(:grub2Widgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs" => fun_ref(method(:Dialogs), "map <string, symbol ()> ()"),
        "write"   => fun_ref(method(:Write), "boolean ()")
      }
    end

    # Constructor
    def BootGRUB2
      Ops.set(
        BootCommon.bootloader_attribs,
        "grub2",
        {
          # we need syslinux to have generic mbr bnc#885496
          "required_packages" => ["grub2", "syslinux"],
          "loader_name"       => "GRUB2",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :function => :grub_updateMBR, :type => "boolean ()"
    publish :function => :ReduceDeviceMapTo8, :type => "boolean ()"
    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :variable => :grub_help_messages, :type => "map <string, string>"
    publish :variable => :grub_descriptions, :type => "map <string, string>"
    publish :variable => :grub2_help_messages, :type => "map <string, string>"
    publish :variable => :grub2_descriptions, :type => "map <string, string>"
    publish :variable => :password, :type => "string"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :grub2Widgets, :type => "map <string, map <string, any>> ()"
    publish :function => :grub2efiWidgets, :type => "map <string, map <string, any>> ()"
    publish :function => :StandardGlobals, :type => "map <string, string> ()"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootGRUB2, :type => "void ()"
  end

  BootGRUB2 = BootGRUB2Class.new
  BootGRUB2.main
end
