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

require "tempfile"
require "yaml"

module Yast
  module BootloaderRoutinesLibIfaceInclude
    def initialize_bootloader_routines_lib_iface(include_target)
      textdomain "bootloader"

      Yast.import "Storage"
      Yast.import "Mode"

      # Loader the library has been initialized to use
      @library_initialized = nil
    end

    STATE_FILE = "/var/lib/YaST2/pbl-state"

    def tmp_yaml_file(data=nil)
      file = Tempfile.new("y2-yamldata")
      file.write YAML.dump(data) if data
      file.close

      return file
    end

    def run_pbl_yaml(*args)
      cmd = "pbl-yaml --state=#{STATE_FILE} "
      cmd << args.map{|e| "'#{e}'"}.join(" ")

      SCR.Execute(path(".target.bash"), cmd)
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

      mp_data = tmp_yaml_file(BootStorage.mountpoints)
      part_data = tmp_yaml_file(BootStorage.partinfo)
      md_data = tmp_yaml_file(BootStorage.md_info)

      run_pbl_yaml "DefineMountPoints(#{mp_data.path})",
        "DefinePartitions(#{part_data.path})",
        "DefineMDArrays(#{md_data.path})"
      DefineMultipath(BootStorage.multipath_mapping)

      nil
    ensure
      mp_data.unlink
      part_data.unlink
      md_data.unlink
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
      loader_data = tmp_yaml_file(loader)
      arch_data = tmp_yaml_file( architecture)
      udev_data = tmp_yaml_file(BootStorage.all_devices)

      run_pbl_yaml "SetLoaderType(#{loader_data.path},#{arch_data.path})",
        "DefineUdevMapping(#{udev_data.path})"

      Builtins.y2milestone("Putting partitioning into library")
      # pass all needed disk/partition information to library
      SetDiskInfo()
      Builtins.y2milestone("Library initialization finished")
      @library_initialized = loader
      true
    ensure
      loader_data.unlink if loader_data
      arch_data.unlink if arch_data
      udev_data.unlink if udev_data
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
      sections_data = tmp_yaml_file(sections)
      run_pbl_yaml "SetSections(#{sections_data.path})"

      true
    ensure
      sections_data.unlink
    end

    # Get boot loader sections
    # @return a list of all loader sections (as maps)
    def GetSections
      sections_data = tmp_yaml_file
      Builtins.y2milestone("Reading bootloader sections")
      run_pbl_yaml "#{sections_data.path}=GetSections()"
      sects = YAML.load File.read(sections_data.path)
      if sects == nil
        Builtins.y2error("Reading sections failed")
        return []
      end
      Builtins.y2milestone("Read sections: %1", sects)

      sects
    ensure
      sections_data.unlink
    end

    # Set global bootloader options
    # @param [Hash{String => String}] globals a map of global bootloader options
    # @return [Boolean] true on success
    def SetGlobal(globals)
      globals = deep_copy(globals)
      Builtins.y2milestone("Storing global settings %1", globals)
      Ops.set(globals, "__modified", "1")
      globals_data = tmp_yaml_file(globals)

      run_pbl_yaml "SetGlobalSettings(#{globals_data.path})"

      true
    ensure
      globals_data.unlink
    end

    # Get global bootloader options
    # @return a map of global bootloader options
    def GetGlobal
      Builtins.y2milestone("Reading bootloader global settings")
      globals_data = tmp_yaml_file
      run_pbl_yaml "#{globals_data.path}=GetGlobalSettings()"
      glob = YAML.load File.read(globals_data.path)

      if glob == nil
        Builtins.y2error("Reading global settings failed")
        return {}
      end

      Builtins.y2milestone("Read global settings: %1", glob)
      glob
    ensure
      globals_data.unlink
    end

    # Set the device mapping (Linux <-> Firmware)
    # @param [Hash{String => String}] device_map a map from Linux device to Firmware device identification
    # @return [Boolean] true on success
    def SetDeviceMap(device_map)
      arg_data = tmp_yaml_file(device_map)

      Builtins.y2milestone("Storing device map")
      run_pbl_yaml "SetDeviceMapping(#{arg_data.path})"

      true
    ensure
      arg_data.unlink
    end

    # Set the mapping (real device <-> multipath)
    # @param  map<string,string> map from real device to multipath device
    # @return [Boolean] true on success
    def DefineMultipath(multipath_map)
      Builtins.y2milestone("Storing multipath map: %1", multipath_map)
      if Builtins.size(multipath_map) == 0
        Builtins.y2milestone("Multipath was not detected")
        return true
      end

      arg_data = tmp_yaml_file(multipath_map)
      run_pbl_yaml "DefineMultipath(#{arg_data.path})"

      true
    ensure
      arg_data.unlink if arg_data
    end


    # Get the device mapping (Linux <-> Firmware)
    # @return a map from Linux device to Firmware device identification
    def GetDeviceMap
      Builtins.y2milestone("Reading device mapping")

      res_data = tmp_yaml_file

      run_pbl_yaml "#{res_data.path}=GetDeviceMap()"

      devmap = YAML.load(File.read(res_data.path))

      if devmap == nil
        Builtins.y2error("Reading device mapping failed")
        return {}
      end

      Builtins.y2milestone("Read device mapping: %1", devmap)
      devmap
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
      param_data = tmp_yaml_file(avoid_reading_device_map)
      Builtins.y2milestone("Reading Files")

      run_pbl_yaml "ReadSettings(#{param_data.path})"

      true
    ensure
      param_data.unlink
    end

    # Flush the internal cache of the library to the disk
    # @return [Boolean] true on success
    def CommitSettings
      Builtins.y2milestone("Writing files to system")
      run_pbl_yaml "WriteSettings()"

      true
    end

    # Update the bootloader settings, make updated saved settings active
    # @return [Boolean] true on success
    def UpdateBootloader
      # true mean avoid init of bootloader
      arg_data = tmp_yaml_file(true)

      Builtins.y2milestone("Updating bootloader configuration")
      run_pbl_yaml "UpdateBootloader(#{arg_data.path})"
    ensure
      arg_data.unlink
    end

    def SetSecureBoot(enable)
      arg_data = tmp_yaml_file(enable)

      Builtins.y2milestone("Set SecureBoot")
      run_pbl_yaml "SetSecureBoot(#{arg_data.path})"

      true
    ensure
      arg_data.unlink
    end


    # Update append in from boot section, it means take value from "console"
    # and add it to "append"
    #
    # @param [String] append from section
    # @param [String] console from section
    # @return [String] updated append with console
    def UpdateSerialConsole(append, console)
      append_data = tmp_yaml_file(append)
      console_data = tmp_yaml_file(console)
      Builtins.y2milestone(
        "Updating append: %1 with console: %2",
        append,
        console
      )

      run_pbl_yaml "UpdateSerialConsole(#{append_data.path},#{console_data.path})"

      true
    ensure
      append_data.unlink
      console_data.unlink
    end

    # Initialize the boot loader (eg. modify firmware, depending on architecture)
    # @return [Boolean] true on success
    def InitializeBootloader
      Builtins.y2milestone("Initializing bootloader")

      run_pbl_yaml "InitializeBootloader()"
    end

    # Get contents of files from the library cache
    # @return a map filename -> contents, empty map in case of fail
    def GetFilesContents
      Builtins.y2milestone("Getting contents of files")
      ret_data = tmp_yaml_file

      run_pbl_yaml "#{res_data.path}=GetFilesContents()"

      ret = YAML.load(File.read(ret_data.path))
      if ret == nil
        Builtins.y2error("Getting contents of files failed")
        return {}
      end

      ret
    ensure
      ret_data.unlink
    end

    # Set the contents of all files to library cache
    # @param [Hash{String => String}] files a map filename -> contents
    # @return [Boolean] true on success
    def SetFilesContents(files)
      files_data = tmp_yaml_file(files)

      Builtins.y2milestone("Storing contents of files")
      run_pbl_yaml "SetFilesContents(#{files_data.path})"

      true
    ensure
      files_data.unlink
    end

    # Analyse content of MBR
    #
    # @param [String] device name ("/dev/sda")
    # @return [String] result of analyse ("GRUB stage1", "uknown",...)

    def examineMBR(device)
      device_data = tmp_yaml_file(device)
      ret_data = tmp_yaml_file

      run_pbl_yaml "#{ret_data.path}=ExamineMBR(#{device_data})"
      ret = YAML.load(File.read(ret_data.path))

      Builtins.y2milestone("Device: %1 includes in MBR: %2", device, ret)
      ret
    ensure
      device_data.unlink
      ret_data.unlink
    end
  end
end
