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
module Yast
  module BootloaderRoutinesLibIfaceInclude
    def initialize_bootloader_routines_lib_iface(include_target)
      textdomain "bootloader"

      Yast.import "System::Bootloader_API"
      Yast.import "Storage"
      Yast.import "Mode"

      # Loader the library has been initialized to use
      @library_initialized = nil
    end

    #  Retrieve the data for perl-Bootloader library from Storage module
    #  and pass it along
    #  @return nothing
    # FIXME: this should be done directly in perl-Bootloader through LibStorage.pm
    def SetDiskInfo
      BootStorage.InitDiskInfo

      Builtins.y2milestone(
        "Information about partitioning: %1",
        BootStorage.partinfo
      )
      Builtins.y2milestone(
        "Information about MD arrays: %1",
        BootStorage.md_info
      )
      Builtins.y2milestone(
        "Mapping real disk to multipath: %1",
        BootStorage.multipath_mapping
      )

      System::Bootloader_API.setMountPoints(
        Convert.convert(
          BootStorage.mountpoints,
          :from => "map <string, any>",
          :to   => "map <string, string>"
        )
      )
      System::Bootloader_API.setPartitions(
        Convert.convert(
          BootStorage.partinfo,
          :from => "list <list>",
          :to   => "list <list <string>>"
        )
      )
      System::Bootloader_API.setMDArrays(BootStorage.md_info)
      DefineMultipath(BootStorage.multipath_mapping)

      nil
    end

    # Initialize the bootloader library
    # @param [Boolean] force boolean true if the initialization is to be forced
    # @param [String] loader string the loader to initialize the library for
    # @return [Boolean] true on success
    def InitializeLibrary(force, loader)
      return false if !force && loader == @library_initialized

      BootStorage.InitMapDevices
      Builtins.y2milestone("Initializing lib for %1", loader)
      architecture = BootArch.StrArch
      System::Bootloader_API.setLoaderType(loader, architecture)
      out = System::Bootloader_API.defineUdevMapping(BootStorage.all_devices)
      if out == nil
        Builtins.y2error("perl-Bootloader library was not initialized")
      end
      Builtins.y2milestone("Putting partitioning into library")
      # pass all needed disk/partition information to library
      SetDiskInfo()
      Builtins.y2milestone("Library initialization finished")
      @library_initialized = loader
      true
    end

    # Set boot loader sections
    # @param [Array<Hash{String => Object>}] sections a list of all loader sections (as maps)
    # @return [Boolean] true on success
    def SetSections(sections)
      sections = deep_copy(sections)
      sections = Builtins.maplist(sections) do |s|
        if Mode.normal
          if Ops.get_boolean(s, "__changed", false) ||
              Ops.get_boolean(s, "__auto", false)
            Ops.set(s, "__modified", "1")
          end
        else
          Ops.set(s, "__modified", "1")
        end
        deep_copy(s)
      end
      Builtins.y2milestone("Storing bootloader sections %1", sections)
      ret = System::Bootloader_API.setSections(sections)
      Builtins.y2error("Storing bootloader sections failed") if !ret
      ret
    end

    # Get boot loader sections
    # @return a list of all loader sections (as maps)
    def GetSections
      Builtins.y2milestone("Reading bootloader sections")
      sects = System::Bootloader_API.getSections
      if sects == nil
        Builtins.y2error("Reading sections failed")
        return []
      end
      Builtins.y2milestone("Read sections: %1", sects)
      deep_copy(sects)
    end

    # Set global bootloader options
    # @param [Hash{String => String}] globals a map of global bootloader options
    # @return [Boolean] true on success
    def SetGlobal(globals)
      globals = deep_copy(globals)
      Builtins.y2milestone("Storing global settings %1", globals)
      Ops.set(globals, "__modified", "1")
      ret = System::Bootloader_API.setGlobalSettings(globals)
      Builtins.y2error("Storing global settings failed") if !ret
      ret
    end

    # Get global bootloader options
    # @return a map of global bootloader options
    def GetGlobal
      Builtins.y2milestone("Reading bootloader global settings")
      glob = System::Bootloader_API.getGlobalSettings
      if glob == nil
        Builtins.y2error("Reading global settings failed")
        return {}
      end
      Builtins.y2milestone("Read global settings: %1", glob)
      deep_copy(glob)
    end

    # Get bootloader configuration meta data such as field type descriptions
    # @return a map of meta data for global and section entries
    def GetMetaData
      Builtins.y2milestone("Reading meta data for global and section settings")
      # FIXME: DiskInfo should be read directly by perl-Bootloader
      # send current disk/partition information to perl-Bootloader
      SetDiskInfo()

      Builtins.y2milestone("Calling getMetaData")
      meta = System::Bootloader_API.getMetaData
      Builtins.y2milestone("Returned from getMetaData")
      if meta == nil
        Builtins.y2error("Reading meta data failed")
        return {}
      end
      Builtins.y2milestone("Read meta data settings: %1", meta)
      deep_copy(meta)
    end

    # Set the device mapping (Linux <-> Firmware)
    # @param [Hash{String => String}] device_map a map from Linux device to Firmware device identification
    # @return [Boolean] true on success
    def SetDeviceMap(device_map)
      device_map = deep_copy(device_map)
      Builtins.y2milestone("Storing device map")
      ret = System::Bootloader_API.setDeviceMapping(device_map)
      Builtins.y2error("Storing device map failed") if !ret
      ret
    end

    # Set the mapping (real device <-> multipath)
    # @param  map<string,string> map from real device to multipath device
    # @return [Boolean] true on success
    def DefineMultipath(multipath_map)
      multipath_map = deep_copy(multipath_map)
      Builtins.y2milestone("Storing multipath map: %1", multipath_map)
      if Builtins.size(multipath_map) == 0
        Builtins.y2milestone("Multipath was not detected")
        return true
      end
      ret = System::Bootloader_API.defineMultipath(multipath_map)
      Builtins.y2error("Storing multipath map failed") if !ret
      ret
    end


    # Get the device mapping (Linux <-> Firmware)
    # @return a map from Linux device to Firmware device identification
    def GetDeviceMap
      Builtins.y2milestone("Reading device mapping")
      devmap = System::Bootloader_API.getDeviceMapping
      if devmap == nil
        Builtins.y2error("Reading device mapping failed")
        return {}
      end
      Builtins.y2milestone("Read device mapping: %1", devmap)
      deep_copy(devmap)
    end

    # Display the log file written by the underlying bootloader libraries
    def bootloaderError(error)
      bl_logfile = "/var/log/YaST2/y2log_bootloader"
      bl_log = Convert.to_string(SCR.Read(path(".target.string"), bl_logfile))

      errorWithLogPopup(
        Builtins.sformat(
          # error popup - label, %1 is bootloader name
          _("Error occurred while installing %1."),
          getLoaderName(getLoaderType(false), :summary)
        ),
        bl_log
      )
      Builtins.y2error("%1", error)

      nil
    end

    # Read the files from the system to internal cache of the library
    # @param [Boolean] avoid_reading_device_map do not read the device map, but use internal
    # data
    # @return [Boolean] true on success
    def ReadFiles(avoid_reading_device_map)
      Builtins.y2milestone("Reading Files")
      ret = System::Bootloader_API.readSettings(avoid_reading_device_map)
      Builtins.y2error("Reading files failed") if !ret
      ret
    end

    # Flush the internal cache of the library to the disk
    # @return [Boolean] true on success
    def CommitSettings
      Builtins.y2milestone("Writing files to system")
      ret = System::Bootloader_API.writeSettings
      bootloaderError("Writing files to system failed") if !ret
      ret
    end

    # Update the bootloader settings, make updated saved settings active
    # @return [Boolean] true on success
    def UpdateBootloader
      Builtins.y2milestone("Updating bootloader configuration")
      ret = System::Bootloader_API.updateBootloader(true)
      Builtins.y2milestone("return value from updateBootloader: %1", ret)
      if !ret
        bootloaderError("Error occurred while updating configuration files")
      end
      ret
    end

    def SetSecureBoot(enable)
      Builtins.y2milestone("Set SecureBoot")
      ret = System::Bootloader_API.setSecureBoot(enable)
      Builtins.y2milestone("return value from setSecureBoot: %1", ret)
      bootloaderError("Error occurred while setting secureboot") if !ret
      ret
    end


    # Update append in from boot section, it means take value from "console"
    # and add it to "append"
    #
    # @param [String] append from section
    # @param [String] console from section
    # @return [String] updated append with console
    def UpdateSerialConsole(append, console)
      Builtins.y2milestone(
        "Updating append: %1 with console: %2",
        append,
        console
      )
      ret = System::Bootloader_API.updateSerialConsole(append, console)
      Builtins.y2milestone("return updated value of append: %1", ret)
      bootloaderError("Error occurred while updating append") if ret == nil
      ret
    end

    # Initialize the boot loader (eg. modify firmware, depending on architecture)
    # @return [Boolean] true on success
    def InitializeBootloader
      Builtins.y2milestone("Initializing bootloader")
      ret = System::Bootloader_API.initializeBootloader
      bootloaderError("Error occurred while initializing bootloader") if !ret
      ret
    end

    # Get contents of files from the library cache
    # @return a map filename -> contents, empty map in case of fail
    def GetFilesContents
      Builtins.y2milestone("Getting contents of files")
      ret = System::Bootloader_API.getFilesContents
      if ret == nil
        Builtins.y2error("Getting contents of files failed")
        return {}
      end
      deep_copy(ret)
    end

    # Set the contents of all files to library cache
    # @param [Hash{String => String}] files a map filename -> contents
    # @return [Boolean] true on success
    def SetFilesContents(files)
      files = deep_copy(files)
      Builtins.y2milestone("Storing contents of files")
      ret = System::Bootloader_API.setFilesContents(files)
      Builtins.y2error("Setting file contents failed") if !ret
      ret
    end

    # Analyse content of MBR
    #
    # @param [String] device name ("/dev/sda")
    # @return [String] result of analyse ("GRUB stage1", "uknown",...)

    def examineMBR(device)
      ret = System::Bootloader_API.examineMBR(device)
      Builtins.y2milestone("Device: %1 includes in MBR: %2", device, ret)
      ret
    end
  end
end
