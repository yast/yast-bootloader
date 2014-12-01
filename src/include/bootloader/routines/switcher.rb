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
    def initialize_bootloader_routines_switcher(_include_target)
      Yast.import "BootGRUB2"
      Yast.import "BootGRUB2EFI"
      Yast.import "BootCommon"
    end

    # Get method for current bootloader
    def get_function(method)
      functions = get_functions(BootCommon.getLoaderType(false))
      ret = functions[method.to_s.downcase]
      if !ret && BootCommon.methods.include?(method)
        ret = BootCommon.method(method)
      end

      ret
    end

    # Get map of main functions for bootloader
    # @param [String] bootloader string bootloader name
    # @return [Hash] of function
    def get_functions(bootloader)
      bl_functions = {
        "grub2"     => BootGRUB2.method(:GetFunctions),
        "grub2-efi" => BootGRUB2EFI.method(:GetFunctions)
      }
      gf = bl_functions[bootloader]
      if !gf
        Builtins.y2warning("No bootloader-specific functions specified for #{bootloader.inspect}")
        return {}
      end
      gf.call
    end

    # Export bootloader-specific settings
    # @return [Hash] of settings
    def blExport
      get_function(:Export).call
    end

    # Import settings to bootloader
    # @param [Hash] settings map of settingss
    # @return [Boolean] true on success
    def blImport(settings)
      get_function(:Import).call(settings)
    end

    # Read bootloader-specific settings
    # @param [Boolean] reread boolean true to force rereading the settings from the disk
    # @return [Boolean] true on success
    def blRead(reread, avoid_reading_device_map)
      get_function(:Read).call(reread, avoid_reading_device_map)
    end

    # Reset bootloader-specific settings
    # @param [Boolean] init boolean true if basic initialization of system-dependent
    # settings should be done
    def blReset(init)
      get_function(:Reset).call(init)
    end

    # Propose bootloader settings
    def blPropose
      get_function(:Propose).call
    end

    # Save bootloader cfg. files to the cache of the pluglib
    # @param [Boolean] clean boolean true to perform checks on the settings
    # @param [Boolean] init boolean true to reinitialize the library
    # @param [Boolean] flush boolean true to flush the settings to the disk
    # @return [Boolean] true on success
    def blSave(clean, init, flush)
      get_function(:Save).call(clean, init, flush)
    end

    # Get cfg. summary
    # @return a list summary items
    def blSummary
      get_function(:Summary).call
    end

    # Update bootloader-specific settings
    def blUpdate
      get_function(:Update).call
    end

    # Do the bootloader installation
    # @return [Boolean] true on success
    def blWrite
      get_function(:Write).call
    end

    # Get description maps of loader-specific widgets
    # @return a map containing description of all loader-specific widgets
    def blWidgetMaps
      method = get_function(:widgets)
      method ? method.call : {}
    end

    # Get the loader-specific dialogs
    # @return a map of loader-specific dialogs
    def blDialogs
      method = get_function(:dialogs)
      method ? method.call : {}
    end

    # Set section to boot on next reboot for this type of bootloader
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def blFlagOnetimeBoot(section)
      method = get_function(:flagonetimeboot)
      method ? method.call(section) : false
    end
  end
end
