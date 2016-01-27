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
require "bootloader/udev_mapping"
require "bootloader/sysconfig"

module Yast
  class BootCommonClass < Module
    SUPPORTED_BOOTLOADERS = [
      "none", # allow user to manage bootloader itself
      "grub2",
      "grub2-efi"
    ]

    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "HTML"
      Yast.import "Mode"
      Yast.import "PackageSystem"
      Yast.import "Storage"
      Yast.import "PackagesProposal"
      Yast.import "BootStorage"

      Yast.import "Linuxrc"

      # General bootloader settings

      # map of global options and values
      @globals = {}

      # Saved change time from target map - proposal

      @cached_settings_base_data_change_time = nil

      # device to save loader stage 1 to
      # NOTE: this variable is being phased out. The boot_* keys in the globals map
      # are now used to remember the selected boot location. Thus, we now have a
      # list of selected loader devices. It can be generated from the information in
      # the boot_* keys and the global variables (Boot|Root|Extended)PartitionDevice
      # and mbrDisk by calling GetBootloaderDevices().
      # FIXME: need remove to read only loader location from perl-Bootloader
      @loader_device = nil

      # proposal helping variables

      # The kind of bootloader location that the user selected last time he went to
      # the dialog. Used as a hint next time a proposal is requested, so the
      # proposal can try to satisfy the user's previous preference.
      # NOTE: this variable is being phased out. The boot_* keys in the globals map
      # will be used to remember the last selected location.
      # Currently, valid values are: mbr, boot, root, mbr_md, none
      # FIXME: need remove to read only loader location from perl-Bootloader
      @selected_location = nil

      # These global variables and functions are needed in included files

      # Parameters of currently used bootloader
      @current_bootloader_attribs = {}

      # Parameters of all bootloaders
      @bootloader_attribs = {}

      # Backup original MBR before installing bootloader
      @backup_mbr = false

      # Activate bootloader partition during installation?
      @activate = false

      # action to do with pbmr flag on boot disk
      # values are :add, :remove or nil, means do nothing
      @pmbr_action = nil

      # were settings changed (== true)
      @changed = false

      # common variables

      # type of bootloader to configure/being configured
      # shall be one of "grub2", "grub2-efi"
      @loader_type = nil
      @secure_boot = nil

      # saving mode setting functions

      # map of save mode settings
      @write_settings = {}

      # other variables

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

      # FATE#305008: Failover boot configurations for md arrays with redundancy
      # if true enable redundancy for md array
      @enable_md_array_redundancy = nil

      # help message and dscription definitions
      Yast.include self, "bootloader/routines/popups.rb"
      Yast.include self, "bootloader/routines/misc.rb"
      # FIXME: there are other archs than i386, this is not 'commmon'
      Yast.include self, "bootloader/routines/lilolike.rb"
    end

    # generic versions of bootloader-specific functions

    # Export bootloader settings to a map
    # @return bootloader settings
    def Export
      exp = {
        "global"     => remapGlobals(@globals),
        "device_map" => BootStorage.device_map.remapped_hash
      }
      exp["activate"] = @activate if @loader_type != "grub2"

      exp
    end

    # Import settings from a map
    # @param [Hash] settings map of bootloader settings
    # @return [Boolean] true on success
    def Import(settings)
      settings = deep_copy(settings)
      @globals = Ops.get_map(settings, "global", {})

      if @loader_type != "grub2"
        @activate = Ops.get_boolean(settings, "activate", false)
      end
      BootStorage.device_map = ::Bootloader::DeviceMap.new(settings["device_map"] || {})
      true
    end

    # Reset bootloader settings
    def Reset
      @globals = {}
      @activate = false
      @activate_changed = false
      @was_proposed = false

      nil
    end

    publish :variable => :globals, :type => "map <string, string>"
    publish :variable => :cached_settings_base_data_change_time, :type => "integer"
    publish :variable => :loader_device, :type => "string"
    publish :variable => :selected_location, :type => "string"
    publish :variable => :current_bootloader_attribs, :type => "map <string, any>"
    publish :variable => :bootloader_attribs, :type => "map <string, map <string, any>>"
    publish :variable => :backup_mbr, :type => "boolean"
    publish :variable => :activate, :type => "boolean"
    publish :variable => :pmbr_action, :type => "symbol"
    publish :variable => :changed, :type => "boolean"
    publish :variable => :write_settings, :type => "map"
    publish :variable => :activate_changed, :type => "boolean"
    publish :variable => :save_all, :type => "boolean"
    publish :variable => :was_proposed, :type => "boolean"
    publish :variable => :was_read, :type => "boolean"
    publish :variable => :location_changed, :type => "boolean"
    publish :variable => :enable_md_array_redundancy, :type => "boolean"
    publish :function => :getLoaderType, :type => "string (boolean)"
    publish :function => :getBootloaders, :type => "list <string> ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :examineMBR, :type => "string (string)"
    publish :function => :ThinkPadMBR, :type => "boolean (string)"
    publish :function => :VerifyMDArray, :type => "boolean ()"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :DetectDisks, :type => "void ()"
    publish :function => :getBootPartition, :type => "string ()"
    publish :function => :getLoaderName, :type => "string (string, symbol)"
    publish :function => :getBooleanAttrib, :type => "boolean (string)"
    publish :function => :getAnyTypeAttrib, :type => "any (string, any)"
    publish :function => :remapGlobals, :type => "map <string, string> (map <string, string>)"
    publish :function => :GetBootloaderDevice, :type => "string ()"
    publish :function => :GetBootloaderDevices, :type => "list <string> ()"
    publish :function => :getKernelParamFromLine, :type => "any (string, string)"
    publish :function => :setKernelParamToLine, :type => "string (string, string, any)"
    publish :function => :restoreMBR, :type => "boolean (string)"
    publish :function => :UpdateInstallationKernelParameters, :type => "void ()"
    publish :function => :BootloaderInstallable, :type => "boolean ()"
    publish :function => :PartitionInstallable, :type => "boolean ()"
    publish :function => :getBootDisk, :type => "string ()"
    publish :function => :DiskOrderSummary, :type => "string ()"
    publish :function => :PostUpdateMBR, :type => "boolean ()"
    publish :function => :UpdateGlobals, :type => "void ()"
    publish :function => :SetDiskInfo, :type => "void ()"
    publish :function => :InitializeLibrary, :type => "boolean (boolean, string)"
    publish :function => :SetSections, :type => "boolean (list <map <string, any>>)"
    publish :function => :GetSections, :type => "list <map <string, any>> ()"
    publish :function => :SetGlobal, :type => "boolean (map <string, string>)"
    publish :function => :GetGlobal, :type => "map <string, string> ()"
    publish :function => :SetDeviceMap, :type => "boolean (map <string, string>)"
    publish :function => :ReadFiles, :type => "boolean (boolean)"
    publish :function => :CommitSettings, :type => "boolean ()"
    publish :function => :UpdateBootloader, :type => "boolean ()"
    publish :function => :InitializeBootloader, :type => "boolean ()"
    publish :function => :GetFilesContents, :type => "map <string, string> ()"
    publish :function => :SetFilesContents, :type => "boolean (map <string, string>)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Reset, :type => "void ()"
  end

  BootCommon = BootCommonClass.new
  BootCommon.main
end
