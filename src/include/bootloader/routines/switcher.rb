# encoding: utf-8

# File:
#      include/bootloader/routines/switcher.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Functions for choosing proper bootloader-specific functions
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
module Yast
  module BootloaderRoutinesSwitcherInclude
    def initialize_bootloader_routines_switcher(include_target)
      Yast.import "BootGRUB"
      Yast.import "BootGRUB2"
      Yast.import "BootGRUB2EFI"
      Yast.import "BootCommon"
    end

    # Get map of main functions for bootloader
    # @param [String] bootloader string bootloader name
    # @return [Hash] of function
    def getFunctions(bootloader)
      return {} if bootloader == nil || bootloader == ""
      bl_functions = {
        "grub"      => fun_ref(
          BootGRUB.method(:GetFunctions),
          "map <string, any> ()"
        ),
        "grub2"     => fun_ref(
          BootGRUB2.method(:GetFunctions),
          "map <string, any> ()"
        ),
        "grub2-efi" => fun_ref(
          BootGRUB2EFI.method(:GetFunctions),
          "map <string, any> ()"
        )
      }
      gf = Convert.convert(
        Ops.get(bl_functions, bootloader),
        :from => "any",
        :to   => "map <string, any> ()"
      )
      if gf == nil
        Builtins.y2warning("No bootloader-specific functions specified")
        return {}
      end
      gf.call
    end

    # Export bootloader-specific settings
    # @return [Hash] of settings
    def blExport
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "export",
          fun_ref(BootCommon.method(:Export), "map ()")
        ),
        :from => "any",
        :to   => "map ()"
      )
      toEval.call
    end

    # Import settings to bootloader
    # @param [Hash] settings map of settingss
    # @return [Boolean] true on success
    def blImport(settings)
      settings = deep_copy(settings)
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "import",
          fun_ref(BootCommon.method(:Import), "boolean (map)")
        ),
        :from => "any",
        :to   => "boolean (map)"
      )
      toEval.call(settings)
    end

    # Read bootloader-specific settings
    # @param [Boolean] reread boolean true to force rereading the settings from the disk
    # @return [Boolean] true on success
    def blRead(reread, avoid_reading_device_map)
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "read",
          fun_ref(BootCommon.method(:Read), "boolean (boolean, boolean)")
        ),
        :from => "any",
        :to   => "boolean (boolean, boolean)"
      )
      toEval.call(reread, avoid_reading_device_map)
    end

    # Reset bootloader-specific settings
    # @param [Boolean] init boolean true if basic initialization of system-dependent
    # settings should be done
    def blReset(init)
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "reset",
          fun_ref(BootCommon.method(:Reset), "void (boolean)")
        ),
        :from => "any",
        :to   => "void (boolean)"
      )
      toEval.call(init)

      nil
    end

    # Propose bootloader settings
    def blPropose
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "propose",
          fun_ref(BootCommon.method(:Propose), "void ()")
        ),
        :from => "any",
        :to   => "void ()"
      )
      toEval.call

      nil
    end

    # Get sections types
    # @return [Array<String>] section types
    def blsection_types
      functions = getFunctions(BootCommon.getLoaderType(false))
      fallback = lambda { ["image"] }
      toEval = Convert.convert(
        Ops.get(
          functions,
          "section_types",
          fun_ref(fallback, "list <string> ()")
        ),
        :from => "any",
        :to   => "list <string> ()"
      )
      toEval.call
    end

    # Save bootloader cfg. files to the cache of the pluglib
    # @param [Boolean] clean boolean true to perform checks on the settings
    # @param [Boolean] init boolean true to reinitialize the library
    # @param [Boolean] flush boolean true to flush the settings to the disk
    # @return [Boolean] true on success
    def blSave(clean, init, flush)
      functions = getFunctions(BootCommon.getLoaderType(false))

      toEval = Convert.convert(
        Ops.get(
          functions,
          "save",
          fun_ref(
            BootCommon.method(:Save),
            "boolean (boolean, boolean, boolean)"
          )
        ),
        :from => "any",
        :to   => "boolean (boolean, boolean, boolean)"
      )
      toEval.call(clean, init, flush)
    end

    # Get cfg. summary
    # @return a list summary items
    def blSummary
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "summary",
          fun_ref(BootCommon.method(:Summary), "list <string> ()")
        ),
        :from => "any",
        :to   => "list <string> ()"
      )
      toEval.call
    end

    # Update bootloader-specific settings
    def blUpdate
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "update",
          fun_ref(BootCommon.method(:Update), "void ()")
        ),
        :from => "any",
        :to   => "void ()"
      )
      toEval.call

      nil
    end

    # Do the bootloader installation
    # @return [Boolean] true on success
    def blWrite
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(
          functions,
          "write",
          fun_ref(BootCommon.method(:Write), "boolean ()")
        ),
        :from => "any",
        :to   => "boolean ()"
      )
      toEval.call
    end

    # Get description maps of loader-specific widgets
    # @return a map containing description of all loader-specific widgets
    def blWidgetMaps
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(functions, "widgets"),
        :from => "any",
        :to   => "map <string, map <string, any>> ()"
      )
      if toEval != nil
        return toEval.call
      else
        return {}
      end
    end

    # Get the loader-specific dialogs
    # @return a map of loader-specific dialogs
    def blDialogs
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(functions, "dialogs"),
        :from => "any",
        :to   => "map <string, symbol ()> ()"
      )
      if toEval != nil
        return toEval.call
      else
        return {}
      end
    end

    # Set section to boot on next reboot for this type of bootloader
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def blFlagOnetimeBoot(section)
      functions = getFunctions(BootCommon.getLoaderType(false))
      toEval = Convert.convert(
        Ops.get(functions, "flagonetimeboot"),
        :from => "any",
        :to   => "boolean (string)"
      )
      if toEval != nil
        return toEval.call(section)
      else
        return false
      end
    end
  end
end
