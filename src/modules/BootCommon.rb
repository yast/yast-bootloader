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

      # list of section
      @sections = []

      # Saved change time from target map - proposal

      @cached_settings_base_data_change_time = nil

      # device to save loader stage 1 to
      # NOTE: this variable is being phased out. The boot_* keys in the globals map
      # are now used to remember the selected boot location. Thus, we now have a
      # list of selected loader devices. It can be generated from the information in
      # the boot_* keys and the global variables (Boot|Root|Extended)PartitionDevice
      # and mbrDisk by calling GetBootloaderDevices().
      #FIXME: need remove to read only loader location from perl-Bootloader
      @loader_device = nil

      # proposal helping variables

      # The kind of bootloader location that the user selected last time he went to
      # the dialog. Used as a hint next time a proposal is requested, so the
      # proposal can try to satisfy the user's previous preference.
      # NOTE: this variable is being phased out. The boot_* keys in the globals map
      # will be used to remember the last selected location.
      # Currently, valid values are: mbr, boot, root, mbr_md, none
      #FIXME: need remove to read only loader location from perl-Bootloader
      @selected_location = nil

      # These global variables and functions are needed in included files

      # Parameters of currently used bootloader
      @current_bootloader_attribs = {}

      # Parameters of all bootloaders
      @bootloader_attribs = {}

      # device holding MBR for bootloader
      @mbrDisk = ""

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

      @additional_failsafe_params = ""

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
      Yast.include self, "bootloader/routines/lib_iface.rb"
    end

    # generic versions of bootloader-specific functions

    # Export bootloader settings to a map
    # @return bootloader settings
    def Export
      exp = {
        "global"     => remapGlobals(@globals),
        "device_map" => BootStorage.device_map.remapped_hash
      }
      if @loader_type != "grub2"
        Ops.set(exp, "activate", @activate)
      end

      deep_copy(exp)
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

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      bl = getLoaderType(false)
      return true if bl == "none"
      InitializeLibrary(reread, bl)
      ReadFiles(avoid_reading_device_map) if reread
      @sections = GetSections()
      @globals = GetGlobal()
      dev_map = GetDeviceMap()

      # convert device names in device map to the kernel device names
      dev_map = Builtins.mapmap(dev_map) do |k, v|
        { ::Bootloader::UdevMapping.to_mountby_device(k) => v }
      end

      BootStorage.device_map = ::Bootloader::DeviceMap.new(dev_map)

      # convert custom boot device names in globals to the kernel device names
      # also, for legacy bootloaders like LILO that still pass device names,
      # convert the stage1_dev
      @globals = Builtins.mapmap(@globals) do |k, v|
        if k == "stage1_dev" || Builtins.regexpmatch(k, "^boot_.*custom$")
          next { k => ::Bootloader::UdevMapping.to_kernel_device(v) }
        else
          next { k => v }
        end
      end

      true
    end

    # Reset bootloader settings
    def Reset
      @sections = []
      @globals = {}
      @activate = false
      @activate_changed = false
      @was_proposed = false

      nil
    end

    # Propose bootloader settings
    def Propose
      Builtins.y2error("No generic propose function available")

      nil
    end

    # Save all bootloader configuration files to the cache of the PlugLib
    # PlugLib must be initialized properly !!!
    # @param [Boolean] clean boolean true if settings should be cleaned up (checking their
    #  correctness, supposing all files are on the disk)
    # @param [Boolean] init boolean true to init the library
    # @param [Boolean] flush boolean true to flush settings to the disk
    # @return [Boolean] true if success
    def Save(_clean, init, flush)
      ret = true

      bl = getLoaderType(false)

      InitializeLibrary(init, bl)

      return true if bl == "none"

      # bnc#589433 -  Install grub into root (/) partition gives error
      @globals.delete("boot_custom") if @globals["boot_custom"] == ""

      # FIXME: give mountby information to perl-Bootloader (or define some
      # better interface), so that perl-Bootloader can use mountby device names
      # for these devices instead. Tracked in bug #248162.

      # convert custom boot device names in globals to the device names
      # indicated by "mountby"
      # also, for legacy bootloaders like LILO that still pass device names,
      # convert the stage1_dev
      my_globals = Builtins.mapmap(@globals) do |k, v|
        if k == "stage1_dev" || Builtins.regexpmatch(k, "^boot_.*custom$")
          next { k => ::Bootloader::UdevMapping.to_mountby_device(v) }
        else
          next { k => v }
        end
      end

      # convert device names in device map to the device names indicated by
      # "mountby"

      Builtins.y2milestone(
        "device map before mapping #{BootStorage.device_map}"
      )
      my_device_mapping = Builtins.mapmap(BootStorage.device_map.to_hash) do |k, v|
        { ::Bootloader::UdevMapping.to_mountby_device(k) => v }
      end
      Builtins.y2milestone("device map after mapping %1", my_device_mapping)

      if VerifyMDArray()
        if !@enable_md_array_redundancy
          my_globals.delete("boot_md_mbr")
        elsif !my_globals["boot_md_mbr"]
          my_globals["boot_md_mbr"] = BootStorage.devices_for_redundant_boot.join(",")
        end
      else
        my_globals.delete("boot_md_mbr")
      end

      Builtins.y2milestone("SetSecureBoot %1", @secure_boot)
      ret &&= SetSecureBoot(@secure_boot)
      ret &&= DefineMultipath(BootStorage.multipath_mapping)
      ret &&= SetDeviceMap(my_device_mapping)
      ret &&= SetSections(@sections)
      ret &&= SetGlobal(my_globals)
      ret &&= CommitSettings() if flush

      # write settings to /etc/sysconfig/bootloader
      sysconf = ::Bootloader::Sysconfig.new(bootloader: bl, secure_boot: @secure_boot)
      sysconf.write

      ret
    end
    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      bl = getLoaderType(false)
      if bl == "none"
        return [
          HTML.Colorize(getLoaderName(getLoaderType(false), :summary), "red")
        ]
      end

      # each Boot* should have own summary, that can differ
      raise "Not implemented for bootloader \"#{bl}\""
    end

    # Update read settings to new version of configuration files
    def Update
      Builtins.y2debug("No generic update function available")

      nil
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      Builtins.y2error("No generic write function available")
      false
    end

    # end of generic versions of bootloader-specific functions
    #-----------------------------------------------------------------------------
    # common functions start

    # bootloader type handling functions

    # Set attributes of specified bootloader to variable containing
    # attributes of currently used bootloader, call its initializer
    # @param [String] loader_type string loader type to initialize
    def setCurrentLoaderAttribs(loader_type)
      Builtins.y2milestone("Setting attributes for bootloader %1", loader_type)
      if !loader_type
        Builtins.y2error("Setting loader type to nil, this is wrong")
        return
      end

      # FIXME: this should be blInitializer in switcher.ycp for code cleanness
      # and understandability
      boot_initializer = Ops.get(@bootloader_attribs, [loader_type, "initializer"])
      if boot_initializer
        Builtins.y2milestone("Running bootloader initializer")
        boot_initializer.call
        Builtins.y2milestone("Initializer finished")
      else
        Builtins.y2error("No initializer found for >>%1<<", loader_type)
        @current_bootloader_attribs = {}
      end

      @current_bootloader_attribs = Builtins.union(
        @current_bootloader_attribs,
        Builtins.eval(Ops.get(@bootloader_attribs, loader_type, {}))
      )

      nil
    end

    # Check whether loader with specified name is supported
    # @param [String] loader string name of loader to check
    # @return [String] the loader name if supported, "none" otherwise
    def SupportedLoader(loader)
      SUPPORTED_BOOTLOADERS.include?(loader) ? loader : "none"
    end

    def boot_efi?
      if Mode.live_installation
        SCR.Execute(path(".target.bash_output"), "modprobe efivars >/dev/null 2>&1")
        return FileUtils.Exists("/sys/firmware/efi/systab")
      else
        return Linuxrc.InstallInf("EFI") == "1"
      end
    end

    # Get currently used bootloader, detect if not set yet
    # @param [Boolean] recheck boolean force checking bootloader
    # @return [String] botloader type
    def getLoaderType(recheck)
      return @loader_type if !recheck && @loader_type
      # read bootloader to use from disk
      if Mode.update || Mode.normal || Mode.repair
        sysconfig = ::Bootloader::Sysconfig.from_system
        @loader_type = sysconfig.bootloader
        if @loader_type && !@loader_type.empty?
          @loader_type = "grub2" if @loader_type == "s390"
          Builtins.y2milestone(
            "Sysconfig bootloader is %1, using",
            @loader_type
          )
          @loader_type = SupportedLoader(@loader_type)
          Builtins.y2milestone(
            "Sysconfig bootloader is %1, using",
            @loader_type
          )
          setCurrentLoaderAttribs(@loader_type)
          return @loader_type
        end
      end
      # detect bootloader
      @loader_type = SCR.Read(path(".probe.boot_arch"))
      # s390,ppc and also old grub now uses grub2 (fate #315753)
      @loader_type = "grub2" if ["s390", "ppc", "grub"].include? @loader_type

      Builtins.y2milestone("Bootloader detection returned %1", @loader_type)
      if (Arch.i386 || Arch.x86_64) && boot_efi?
        # use grub2-efi as default bootloader for x86_64/i386 EFI
        @loader_type = "grub2-efi"
      end

      @loader_type = SupportedLoader(@loader_type)
      Builtins.y2milestone("Detected bootloader %1", @loader_type)
      setCurrentLoaderAttribs(@loader_type)
      @loader_type
    end

    # set type of bootloader
    # @param [String] bootloader string type of bootloader
    def setLoaderType(bootloader)
      if !bootloader
        Builtins.y2milestone("Resetting the loader type")
        @loader_type = nil
      end
      Builtins.y2milestone("Setting bootloader to >>%1<<", bootloader)
      raise "Unsupported bootloader '#{bootloader}'" unless SUPPORTED_BOOTLOADERS.include?(bootloader)

      bootloader_packages = Ops.get_list(
        @bootloader_attribs,
        [bootloader, "required_packages"],
        []
      )

      # added kexec-tools fate# 303395
      # if kexec option is equal 0 or running live installation
      # doesn't install kexec-tools
      if !Mode.live_installation && Linuxrc.InstallInf("kexec_reboot") != "0"
        bootloader_packages = Builtins.add(bootloader_packages, "kexec-tools")
      end

      # we need perl-Bootloader-YAML API to communicate with pbl
      bootloader_packages << "perl-Bootloader-YAML"

      Builtins.y2milestone("Bootloader packages: %1", bootloader_packages)

      # don't configure package manager during autoinstallation preparing
      if Mode.normal
        PackageSystem.InstallAll(bootloader_packages)
      elsif Stage.initial
        bootloader_packages.each do |p|
          Builtins.y2milestone("Select bootloader package: %1", p)
          PackagesProposal.AddResolvables("yast2-bootloader", :package, [p])
        end
      end
      @loader_type = bootloader
      setCurrentLoaderAttribs(@loader_type)
      Builtins.y2milestone("Loader type set")

      nil
    end

    def getSystemSecureBootStatus(recheck)
      return @secure_boot if !recheck && !@secure_boot.nil?

      if Mode.update || Mode.normal || Mode.repair
        @secure_boot = ::Bootloader::Sysconfig.from_system.secure_boot
      else
        # propose secure boot always to true (bnc#872054), otherwise respect user choice
        @secure_boot = true
      end

      @secure_boot
    end

    def setSystemSecureBootStatus(enable)
      Builtins.y2milestone("Set secure boot: %2 => %1", enable, @secure_boot)
      @location_changed = true if @secure_boot != enable # secure boot require reinstall of stage 1
      @secure_boot = enable

      nil
    end

    # List bootloaders available for configured architecture
    # @return a list of bootloaders
    def getBootloaders
      if Mode.config
        # default means bootloader use what it think is the best
        return SUPPORTED_BOOTLOADERS + ["default"]
      end
      ret = [getLoaderType(false)]
      if Arch.i386 || Arch.x86_64 || Arch.s390 || Arch.ppc
        ret << "grub2"
      end
      if Arch.x86_64
        ret << "grub2-efi"
      end
      ret = Builtins.add(ret, "none")
      # avoid double entry for selected one
      ret.uniq
    end

    # FATE#305008: Failover boot configurations for md arrays with redundancy
    # Verify if proposal includes md array with more diferent disks
    #
    # @return [Boolean] true if there is md array based on more disks
    def VerifyMDArray
      if @globals["boot_md_mbr"]
        md_array = @globals["boot_md_mbr"]
        disks = md_array.split(",").reject(&:empty?)
        if Builtins.size(disks) > 1
          Builtins.y2milestone("boot_md_mbr includes disks: %1", disks)
          return true
        end
      end
      return false
    end

    # FIXME: just backward compatible interface, call directly BootStorage
    def Md2Partitions(md_device)
      BootStorage.Md2Partitions(md_device)
    end

    publish :variable => :globals, :type => "map <string, string>"
    publish :variable => :sections, :type => "list <map <string, any>>"
    publish :variable => :cached_settings_base_data_change_time, :type => "integer"
    publish :variable => :loader_device, :type => "string"
    publish :variable => :selected_location, :type => "string"
    publish :variable => :current_bootloader_attribs, :type => "map <string, any>"
    publish :variable => :bootloader_attribs, :type => "map <string, map <string, any>>"
    publish :variable => :mbrDisk, :type => "string"
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
    publish :function => :getSystemSecureBootStatus, :type => "boolean (boolean)"
    publish :function => :getBootloaders, :type => "list <string> ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :UpdateSerialConsole, :type => "string (string, string)"
    publish :function => :examineMBR, :type => "string (string)"
    publish :function => :ThinkPadMBR, :type => "boolean (string)"
    publish :function => :VerifyMDArray, :type => "boolean ()"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :Md2Partitions, :type => "map <string, integer> (string)"
    publish :function => :DetectDisks, :type => "void ()"
    publish :function => :getBootPartition, :type => "string ()"
    publish :function => :getLoaderName, :type => "string (string, symbol)"
    publish :function => :getBooleanAttrib, :type => "boolean (string)"
    publish :function => :getAnyTypeAttrib, :type => "any (string, any)"
    publish :function => :remapGlobals, :type => "map <string, string> (map <string, string>)"
    publish :function => :GetBootloaderDevice, :type => "string ()"
    publish :function => :GetBootloaderDevices, :type => "list <string> ()"
    publish :function => :getKernelParamFromLine, :type => "string (string, string)"
    publish :function => :setKernelParamToLine, :type => "string (string, string, string)"
    publish :function => :restoreMBR, :type => "boolean (string)"
    publish :function => :getSwapPartitions, :type => "map <string, integer> ()"
    publish :function => :UpdateInstallationKernelParameters, :type => "void ()"
    publish :function => :GetAdditionalFailsafeParams, :type => "string ()"
    publish :function => :BootloaderInstallable, :type => "boolean ()"
    publish :function => :PartitionInstallable, :type => "boolean ()"
    publish :function => :getBootDisk, :type => "string ()"
    publish :function => :HandleConsole2, :type => "void ()"
    publish :function => :GetSerialFromAppend, :type => "void ()"
    publish :function => :DiskOrderSummary, :type => "string ()"
    publish :function => :PostUpdateMBR, :type => "boolean ()"
    publish :function => :FindMBRDisk, :type => "string ()"
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
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Reset, :type => "void ()"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :setLoaderType, :type => "void (string)"
    publish :function => :setSystemSecureBootStatus, :type => "void (boolean)"
  end

  BootCommon = BootCommonClass.new
  BootCommon.main
end
