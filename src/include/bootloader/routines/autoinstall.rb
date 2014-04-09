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
    def initialize_bootloader_routines_autoinstall(include_target)
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

      Yast.import "Bootloader"
      Yast.import "BootStorage"
      Yast.import "BootCommon"
      Yast.import "Initrd"
      Yast.import "Kernel"
      Yast.import "Mode"
    end

    # Add missing data (eg. root filesystem) to sections imported from profile
    # @param [Array<Hash{String => Object>}] sect a list of all sections
    # @return a lit of all updated sections
    def UpdateImportedSections(sect)
      sect = deep_copy(sect)
      sect = Builtins.maplist(sect) do |s|
        Builtins.y2milestone("Updating imported section %1", s)
        orig_name = Ops.get_string(
          s,
          "original_name",
          Ops.get_string(s, "name", "linux")
        )
        type = Ops.get_string(s, "type", "image")
        next deep_copy(s) if type != "image"
        s = Convert.convert(
          Builtins.union(BootCommon.CreateLinuxSection(orig_name), s),
          :from => "map",
          :to   => "map <string, any>"
        )
        # convert "kernel" to "image", if not already defined in the section
        if Builtins.haskey(s, "kernel")
          if !Builtins.haskey(s, "image")
            Ops.set(s, "image", Ops.get_string(s, "kernel", ""))
          end
          s = Builtins.remove(s, "kernel")
        end
        # convert "vga" to "vgamode", if not already defined in the section
        if Builtins.haskey(s, "vga")
          if !Builtins.haskey(s, "vgamode")
            Ops.set(s, "vgamode", Ops.get_string(s, "vga", ""))
          end
          s = Builtins.remove(s, "vga")
        end
        deep_copy(s)
      end
      deep_copy(sect)
    end

    # Translate the autoinstallation map to the Export map
    # @param [Hash{String => Object}] ai a map the autoinstallation map
    # @return a map the export map
    def AI2Export(ai)
      ai = deep_copy(ai)
      BootCommon.DetectDisks if Mode.autoinst
      # prepare settings for default bootloader if not specified in the
      # profile
      if Mode.autoinst &&
          (Ops.get_string(ai, "loader_type", "default") == "default" ||
            Ops.get_string(ai, "loader_type", "default") == "")
        Ops.set(ai, "loader_type", Bootloader.getLoaderType)
      end
      Builtins.y2milestone("Bootloader settings from profile: %1", ai)

      # bootloader type and location stuff
      exp = {
        "loader_type" => Ops.get_string(ai, "loader_type", ""),
        "specific"    => {}
      }

      # define "global" sub-map to make sure we can add to the globals at
      # any time
      Ops.set(exp, ["specific", "global"], {})

      # LILO and GRUB stuff

      old_key_to_new_global_key = {
        "repl_mbr" => "generic_mbr",
        "activate" => "activate"
      }

      if Ops.get_string(ai, "loader_type", "") == "grub"
        Builtins.foreach(["repl_mbr", "activate"]) do |k|
          if Builtins.haskey(ai, k)
            if Ops.get_string(ai, "loader_type", "") == "grub"
              # NOTE: repl_mbr and activate have an effect for lilo,
              # for grub they are only accepted for backwards
              # compatibility (we use globals["generic_mbr"] and
              # globals["activate"] there); anyhow, an existing
              # new-style key in the global map from autoyast has
              # precedence over the old-style key (and will
              # overwrite this later when we import it from the ai
              # map)
              Ops.set(
                exp,
                ["specific", "global", Ops.get(old_key_to_new_global_key, k)],
                Ops.get_boolean(ai, k, false) ? "true" : "false"
              )
              Builtins.y2milestone(
                "converted old key %1 to key %2 in globals: %3",
                k,
                Ops.get(old_key_to_new_global_key, k),
                Ops.get(exp, ["specific", "global"])
              )
            else
              Ops.set(exp, ["specific", k], Ops.get(ai, k))
            end
          end
        end
        # loader_location needs other default and key
        #
        # NOTE: loader_device and loader_location (aka selected_location
        # internally) have an effect for lilo, for grub loader_location is
        # only accepted for backwards compatibility, but loader_device is
        # ignored (FIXME: can we map this to the boot_* variables, or is
        # the target map not yet available?)
        # (we use globals["boot_*"] for these functions now)
        # anyhow, an existing new-style boot_* key in the global map from
        # autoyast has precedence over the settings from the old-style key
        # (and it will be overwritten later when we import the boot_* keys
        # from the ai map)
        if Ops.get_string(ai, "loader_type", "") == "grub" &&
            Builtins.haskey(ai, "location")
          if Ops.get(ai, "location") == "extended"
            Ops.set(exp, ["specific", "global", "boot_extended"], "true")
          elsif Ops.get(ai, "location") == "boot"
            Ops.set(exp, ["specific", "global", "boot_boot"], "true")
          elsif Ops.get(ai, "location") == "root"
            Ops.set(exp, ["specific", "global", "boot_root"], "true")
          elsif Ops.get(ai, "location") == "mbr"
            Ops.set(exp, ["specific", "global", "boot_mbr"], "true")
          elsif Ops.get(ai, "location") == "mbr_md"
            Ops.set(exp, ["specific", "global", "boot_mbr"], "true")
          end
        else
          Ops.set(
            exp,
            "loader_location",
            Ops.get_string(ai, "location", "custom")
          )
        end

        Builtins.foreach(
          ["loader_device"] #"loader_location",
        ) { |k| Ops.set(exp, k, Ops.get(ai, k)) if Builtins.haskey(ai, k) }
      end # LILO and GRUB stuff

      # device map stuff
      if Ops.greater_than(Builtins.size(Ops.get_list(ai, "device_map", [])), 0)
        dm = Ops.get_list(ai, "device_map", [])
        if dm != nil && Ops.greater_than(Builtins.size(dm), 0)
          device_map = Builtins.listmap(dm) do |entry|
            firmware = Builtins.deletechars(
              Ops.get(entry, "firmware", ""),
              "()"
            )
            { Ops.get(entry, "linux", "") => firmware }
          end
          Ops.set(exp, ["specific", "device_map"], device_map)
          # accept everything
          BootStorage.bois_id_missing = false
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
        Ops.set(exp, "initrd", { "list" => modlist, "settings" => modsett })
      end

      old_format = false

      # section stuff
      section_names = []
      if Ops.greater_than(Builtins.size(Ops.get_list(ai, "sections", [])), 0)
        Builtins.foreach(Ops.get_list(ai, "sections", [])) do |s|
          old_format = true if !Ops.is(s, "map <string, any>")
        end
        if !old_format
          sect = Ops.get_list(ai, "sections", [])
          sect = UpdateImportedSections(sect)
          Ops.set(exp, ["specific", "sections"], sect)
          section_names = Builtins.maplist(sect) do |s|
            Ops.get_string(s, "name", "")
          end
        end
      end

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

        sections = Ops.get_list(ai, "sections", [])
        globals = Ops.get_list(ai, "global", [])
        sections = Builtins.prepend(sections, globals)
        flat = Builtins.flatten(sections)
        loader = Ops.get_string(ai, "loader_type", "")
        separator = loader == "grub" ? " " : " = "
        lines = Builtins.maplist(flat) do |f|
          Builtins.sformat(
            "%1%2%3",
            Ops.get_string(f, "key", ""),
            separator,
            Ops.get(f, "value") == nil ? "" : Ops.get(f, "value")
          )
        end
        file = Builtins.mergestring(lines, "\n")
        BootCommon.InitializeLibrary(true, loader)
        BootCommon.SetDeviceMap(BootStorage.device_mapping)
        BootCommon.SetSections([])
        BootCommon.SetGlobal({})
        files = BootCommon.GetFilesContents
        bl2file =
          # TODO the other bootloaders
          { "grub" => "/boot/grub/menu.lst"}
        Ops.set(files, Ops.get(bl2file, loader, ""), file)
        BootCommon.SetFilesContents(files)
        Ops.set(exp, ["specific", "global"], BootCommon.GetGlobal)
        sect = BootCommon.GetSections
        sect = UpdateImportedSections(sect)
        Ops.set(exp, ["specific", "sections"], sect)
        section_names = Builtins.maplist(sect) do |s|
          Ops.get_string(s, "name", "")
        end
      end

      if Builtins.haskey(
          Ops.get_map(exp, ["specific", "global"], {}),
          "default"
        ) &&
          !Builtins.contains(
            section_names,
            Ops.get_string(exp, ["specific", "global", "default"], "")
          )
        Ops.set(
          exp,
          ["specific", "global"],
          Builtins.remove(
            Ops.get_map(exp, ["specific", "global"], {}),
            "default"
          )
        )
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
      glob = Builtins.filter(Ops.get_map(exp, ["specific", "global"], {})) do |k, v|
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
      # sections stuff
      Ops.set(
        ai,
        "sections",
        Builtins.maplist(Ops.get_list(exp, ["specific", "sections"], [])) do |s|
          s = Builtins.filter(s) { |k, v| Builtins.substring(k, 0, 2) != "__" }
          deep_copy(s)
        end
      )

      # LILO and GRUB stuff
      if Ops.get_string(ai, "loader_type", "") == "grub"
        # FIXME: repl_mbr and activate are obsolete for GRUB, no need to
        # look for them in the export map any more (but does not really do
        # any harm)
        Builtins.foreach(["repl_mbr", "activate"]) do |k|
          if Builtins.haskey(Ops.get_map(exp, "specific", {}), k)
            Ops.set(ai, k, Ops.get(exp, ["specific", k]))
          end
        end
        # FIXME: loader_device and loader_location (aka selected_location
        # internally) are obsolete for GRUB, no need to look for them in
        # the export map any more (but does not really do any harm)
        if Builtins.haskey(exp, "loader_location")
          Ops.set(ai, "location", Ops.get_string(exp, "loader_location", ""))
        end
        Builtins.foreach(["loader_device"]) do |k|
          Ops.set(ai, k, Ops.get(exp, k)) if Builtins.haskey(exp, k)
        end
      end

      # device map stuff
      if Ops.greater_than(
          Builtins.size(Ops.get_map(exp, ["specific", "device_map"], {})),
          0
        )
        device_map = Ops.get_map(exp, ["specific", "device_map"], {})
        Builtins.y2error("DM: %1", device_map)
        if device_map != nil && Ops.greater_than(Builtins.size(device_map), 0)
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
