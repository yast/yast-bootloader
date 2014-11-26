# encoding: utf-8

# File:
#      autoinstall.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Bootloader autoinstallation preparation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
module Yast
  module BootloaderRoutinesAutoinstallInclude
    def initialize_bootloader_routines_autoinstall(_include_target)
      # Example autoyast configuration file snippets:
      #
      # -------------------------------------------------
      # SLES9:
      #
      # <bootloader>
      #   <activate config:type="boolean">true</activate>
      #   <board_type>chrp</board_type>
      #   <default>linux</default>
      #   <global config:type="list">
      #     <global_entry>
      #       <key>default</key>
      #       <value>linux</value>
      #     </global_entry>
      #     <global_entry>
      #       <key>timeout</key>
      #       <value config:type="integer">100</value>
      #     </global_entry>
      #     <global_entry>
      #     [...]
      # </global>
      # <initrd_modules config:type="list">
      #   <initrd_module>
      #     <module>sym53c8xx</module>
      #   </initrd_module>
      #   <initrd_module>
      #     <module>loop</module>
      #   </initrd_module>
      # </initrd_modules>
      # <loader_device>/dev/sda1</loader_device>
      # <loader_type>ppc</loader_type>
      # <location>boot</location>
      # <of_defaultdevice config:type="boolean">true</of_defaultdevice>
      # <prep_boot_partition>/dev/sda1</prep_boot_partition>
      # <sections config:type="list">
      #   <section config:type="list">
      #     <section_entry>
      #       <key>image</key>
      #       <value>/boot/vmlinux</value>
      #     </section_entry>
      #     <section_entry>
      #       <key>label</key>
      #       <value>linux</value>
      #     </section_entry>
      #     [...]
      # -------------------------------------------------
      # openSUSE 10.3 Alpha5:
      #
      # <bootloader>
      #   <global>
      #     <activate>true</activate>
      #     <boot_chrp_custom>/dev/sda1</boot_chrp_custom>
      #     <default>linux</default>
      #     <lines_cache_id>1</lines_cache_id>
      #     <timeout config:type="integer">80</timeout>
      #   </global>
      #   <initrd_modules config:type="list">
      #     <initrd_module>
      #       <module>ipr</module>
      #     </initrd_module>
      #     <initrd_module>
      #       <module>pata_pdc2027x</module>
      #     </initrd_module>
      #     <initrd_module>
      #       <module>dm_mod</module>
      #     </initrd_module>
      #   </initrd_modules>
      #   <loader_type>ppc</loader_type>
      #   <sections config:type="list">
      #     <section>
      #       <append> xmon=on sysrq=1</append>
      #       <image>/boot/vmlinux-2.6.22-rc4-git3-2-ppc64</image>
      #       <initial>1</initial>
      #       <initrd>/boot/initrd-2.6.22-rc4-git3-2-ppc64</initrd>
      #       <kernel>/boot/vmlinux</kernel>
      #       <lines_cache_id>0</lines_cache_id>
      #       <name>linux</name>
      #       <original_name>linux</original_name>
      #       <root>/dev/system/root2</root>
      #       <type>image</type>
      #     </section>
      #   </sections>
      # </bootloader>
      # -------------------------------------------------
      textdomain "bootloader"

      Yast.import "Bootloader"
      Yast.import "BootStorage"
      Yast.import "BootCommon"
      Yast.import "Initrd"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Popup"
    end

    # Translate the autoinstallation map to the Export map
    # @param [Hash{String => Object}] ai a map the autoinstallation map
    # @return a map the export map
    def AI2Export(ai)
      ai = deep_copy(ai)

      # bootloader type and location stuff
      exp = {
        "loader_type" => Ops.get_string(ai, "loader_type", ""),
        "specific"    => {}
      }

      unsupported_bootloaders = ["grub", "zipl", "plilo", "lilo", "elilo"]
      if ai["loader_type"] && unsupported_bootloaders.include?(exp["loader_type"].downcase)
        # FIXME: this should be better handled by exception and show it properly, but it require too big change now
        Popup.Error(_("Unsupported bootloader '%s'. Adapt your AutoYaST profile accordingly.") %
 exp["loader_type"])
        return nil
      end

      BootCommon.DetectDisks if Mode.autoinst
      # prepare settings for default bootloader if not specified in the
      # profile
      if Mode.autoinst &&
          (Ops.get_string(ai, "loader_type", "default") == "default" ||
            Ops.get_string(ai, "loader_type", "default") == "")
        Ops.set(ai, "loader_type", Bootloader.getLoaderType)
      end
      Builtins.y2milestone("Bootloader settings from profile: %1", ai)

      # define "global" sub-map to make sure we can add to the globals at
      # any time
      Ops.set(exp, ["specific", "global"], {})

      # device map stuff
      if Ops.greater_than(Builtins.size(Ops.get_list(ai, "device_map", [])), 0)
        dm = Ops.get_list(ai, "device_map", [])
        if !dm.nil? && Ops.greater_than(Builtins.size(dm), 0)
          device_map = Builtins.listmap(dm) do |entry|
            firmware = Builtins.deletechars(
              Ops.get(entry, "firmware", ""),
              "()"
            )
            { Ops.get(entry, "linux", "") => firmware }
          end
          Ops.set(exp, ["specific", "device_map"], device_map)
        end
      end

      # initrd stuff
      modlist = []
      modsett = {}
      Builtins.foreach(Ops.get_list(ai, "initrd_modules", [])) do |mod|
        modlist = Builtins.add(modlist, Ops.get_string(mod, "module", ""))
        modsett = Builtins.add(
          modsett,
          Ops.get_string(mod, "module", ""),
          Ops.get_map(mod, "module_args", {})
        )
      end
      if Mode.autoinst
        current = Initrd.Export
        Builtins.y2milestone(
          "Automatically detected initrd modules: %1",
          current
        )
        modules = Ops.get_list(current, "list", [])
        modules_settings = Ops.get_map(current, "settings", {})
        Builtins.foreach(modules) do |m|
          if !Builtins.contains(modlist, m)
            # add only if it isn't present
            modlist = Builtins.add(modlist, m)
          end
          if !Builtins.haskey(modsett, m) &&
              Builtins.haskey(modules_settings, m)
            # if the argument is in profile, prefer it
            Ops.set(modsett, m, Ops.get(modules_settings, m))
          end
        end
        parameters = Ops.get_string(ai, "kernel_parameters", "")
        if Ops.greater_than(Builtins.size(parameters), 0)
          Builtins.foreach(Builtins.splitstring(parameters, " ")) do |parameter|
            param_value_list = Builtins.splitstring(parameter, "=")
            if Ops.greater_than(Builtins.size(param_value_list), 0)
              Kernel.AddCmdLine(
                Ops.get_string(param_value_list, 0, ""),
                Ops.get_string(param_value_list, 1, "")
              )
            end
          end
        end
      end

      if Ops.greater_than(Builtins.size(modlist), 0)
        Ops.set(exp, "initrd",  "list" => modlist, "settings" => modsett )
      end

      old_format = false

      # global stuff
      if !Builtins.haskey(ai, "global") || Ops.is_map?(Ops.get(ai, "global"))
        Ops.set(
          exp,
          ["specific", "global"],
          Builtins.mapmap(Ops.get_map(ai, "global", {})) do |k, v|
            { k => Builtins.sformat("%1", v) }
          end
        ) # old format
      else
        old_format = true
      end
      Builtins.y2milestone("SLES9 format detected: %1", old_format)
      if old_format
        # In SLES9, there were no specific tags defined for the bootloader
        # configuration items in the <global> and <sections> scopes. All
        # configuration lines there were put into <key> and <value> pairs,
        # and each of these pairs were put into <(global|section)_entry>
        # tags (see example config snippets above).
        # Converting key/value pairs to file contents first, then setting
        # as file contents and re-exporting the parsed file contents.

        globals = Ops.get_list(ai, "global", [])
        loader = Ops.get_string(ai, "loader_type", "")
        separator = " = "
        lines = Builtins.maplist(globals) do |f|
          Builtins.sformat(
            "%1%2%3",
            Ops.get_string(f, "key", ""),
            separator,
            Ops.get(f, "value").nil? ? "" : Ops.get(f, "value")
          )
        end
        files = Builtins.mergestring(lines, "\n")
        BootCommon.InitializeLibrary(true, loader)
        BootCommon.SetDeviceMap(BootStorage.device_map.to_hash)
        BootCommon.SetGlobal({})
        BootCommon.SetFilesContents(files)
        Ops.set(exp, ["specific", "global"], BootCommon.GetGlobal)
      end

      deep_copy(exp)
    end

    # Translate the Export map to the autoinstallation map
    # @param [Hash{String => Object}] exp a map the export map
    # @return a map the autoinstallation map
    def Export2AI(exp)
      exp = deep_copy(exp)
      # bootloader type and location stuff
      ai = { "loader_type" => Ops.get_string(exp, "loader_type", "default") }
      glob = Builtins.filter(Ops.get_map(exp, ["specific", "global"], {})) do |k, _v|
        Builtins.substring(k, 0, 2) != "__"
      end
      # global options stuff
      if Ops.greater_than(Builtins.size(glob), 0)
        Ops.set(ai, "global", Builtins.mapmap(glob) do |k, v|
          if k == "timeout"
            next { k => Builtins.tointeger(v) }
          elsif k == "embed_stage1.5"
            next { k => v == "0" || v == "" ? false : true }
          end
          { k => v }
        end)
      end
      # device map stuff
      if !exp.fetch("specific", {}).fetch("device_map", {}).empty?
        device_map = Ops.get_map(exp, ["specific", "device_map"], {})
        Builtins.y2milestone("DM: %1", device_map)
        if !device_map.nil? && Ops.greater_than(Builtins.size(device_map), 0)
          dm = Builtins.maplist(device_map) do |linux, firmware|
            { "linux" => linux, "firmware" => firmware }
          end
          Ops.set(ai, "device_map", dm)
        end
      end

      # initrd stuff
      ayinitrd = Builtins.maplist(Ops.get_list(exp, ["initrd", "list"], [])) do |m|
        tmp = {}
        Ops.set(tmp, "module", m)
        if Ops.get_map(exp, ["initrd", "settings", m], {}) != {}
          Ops.set(
            tmp,
            "module_args",
            Ops.get_map(exp, ["initrd", "settings", m], {})
          )
        end
        deep_copy(tmp)
      end
      if Ops.greater_than(Builtins.size(ayinitrd), 0)
        Ops.set(ai, "initrd_modules", ayinitrd)
      end

      deep_copy(ai)
    end
  end
end
