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

require "bootloader/udev_mapping"

module Yast
  module BootloaderRoutinesMiscInclude
    def initialize_bootloader_routines_misc(_include_target)
      textdomain "bootloader"
      Yast.import "Mode"
      Yast.import "Stage"

      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Report"
      Yast.import "Kernel"
      Yast.import "Misc"
      Yast.import "ProductFeatures"
      Yast.import "Directory"
      Yast.import "Installation"
      Yast.import "FileUtils"
      Yast.import "String"
    end

    # return printable name of bootloader
    # @param [String] bootloader string bootloader type internal string
    # @param [Symbol] mode symbol `combo or `summary (because of capitalization)
    # @return [String] printable bootloader name
    def getLoaderName(bootloader, mode)
      if bootloader == "none"
        if mode == :summary
          # summary string
          return _("Do not install any boot loader")
        else
          # combo box item
          return _("Do Not Install Any Boot Loader")
        end
      end
      if bootloader == "default"
        if mode == :summary
          # summary string
          return _("Install the default boot loader")
        else
          # combo box item
          return _("Install Default Boot Loader")
        end
      end
      if mode == :summary
        # summary string
        fallback_name = _("Boot loader")
      else
        # combo box item
        fallback_name = _("Boot Loader")
      end
      # fallback bootloader name, keep short
      Ops.get_string(
        @bootloader_attribs,
        [bootloader, "loader_name"],
        fallback_name
      )
    end

    # Get value of specified boolean bootloader attribute
    # @param [String] attrib string attribute name
    # @return [Boolean] value of attribute
    def getBooleanAttrib(attrib)
      Ops.get_boolean(@current_bootloader_attribs, attrib, false)
    end

    # Get value of specified bootloader attribute
    # @param [String] attrib string attribute name
    # @param [Object] defaultv any default value of the attribute (if not found)
    # @return [Object] value of attribute
    def getAnyTypeAttrib(attrib, defaultv)
      defaultv = deep_copy(defaultv)
      Ops.get(@current_bootloader_attribs, attrib, defaultv)
    end

    # other misc functions

    # Function remap globals settings "boot_custom" device name (/dev/sda)
    # or to label (ufo_partition)
    # @param map<string,string> globals
    # @return [Hash{String => String}] globals

    def remapGlobals(globals_set)
      return globals_set if !Arch.ppc && Storage.GetDefaultMountBy == :label

      globals_set["boot_custom"] &&=
        ::Bootloader::UdevMapping.to_kernel_device(globals_set["boot_custom"])

      globals_set
    end

    # Get bootloader device for specified location
    # FIXME: this function is being phased out. Keeping it around until
    # selected_location and loader_device can be dropped for all bootloader
    # types.
    # @return [String] device name
    def GetBootloaderDevice
      return @mbrDisk if @selected_location == "mbr"
      return BootStorage.BootPartitionDevice if @selected_location == "boot"
      return BootStorage.RootPartitionDevice if @selected_location == "root"
      return "mbr_md" if @selected_location == "mbr_md"
      return "/dev/null" if @selected_location == "none"
      @loader_device
    end

    # Get list of bootloader device names for all selected or specified
    # locations
    # @return [Array] device names
    def GetBootloaderDevices
      ret = []
      ret << BootStorage.BootPartitionDevice if @globals["boot_boot"] == "true"
      ret << BootStorage.RootPartitionDevice if @globals["boot_root"] == "true"
      ret << @mbrDisk if @globals["boot_mbr"] == "true"
      ret << BootStorage.ExtendedPartitionDevice if @globals["boot_extended"] == "true"
      ret << @globals["boot_custom"] if @globals["boot_custom"] && !@globals["boot_custom"].empty?
      Builtins.y2warning("Empty bootloader devices. Globals #{@globals.inspect}") if ret.empty?

      ret
    end

    # get kernel parameter values from kernel command line
    #
    # @param [String] line string original line
    # @param [String] key string parameter key
    # @return [String,Array<String>] value, "false" if not present or "true" if present without
    #   value. If the parameter has on more than 1 value, an array will be returned.
    def getKernelParamFromLine(line, key)
      # FIXME: this doesn't work with quotes and spaces
      res = "false"
      # we can get nil if params is not yet proposed, so return not there (bnc#902397)
      return res unless line
      params = line.split(" ").reject(&:empty?)
      values = params.map { |p| kernel_param_parts(p) }.select { |p| p[0] == key }.map(&:last).uniq
      if values.empty? # not present
        "false"
      elsif values.size == 1 # only one value
        values.first
      else # more than 1 value
        values
      end
    end

    def kernel_param_key(param)
      param.split("=").first
    end

    # Split kernel parameters into [key, value] form
    #
    # It also takes care about converting parameters without a value
    # (ie. "quiet" will be ["quiet", "true"]).
    #
    # @param [String] param   Parameter string in "key=value" form.
    # @return [Array<String>] Parameter key and value.
    def kernel_param_parts(param)
      key, value = param.split("=")
      [key, value || "true"]
    end

    # set kernel parameter to GRUB command line
    # @param [String] line string original line
    # @param [String] key string parameter key
    # @param [String,Array<String>] values string (or array of strings) containing values,
    #   "false" to remove key, "true" to add key without value
    # @return [String] new kernel command line
    def setKernelParamToLine(line, key, values)
      line ||= ""
      # bnc#945479, see last line of this method
      line = "" if line == '""'
      # FIXME: this doesn't work with quotes and spaces
      params = line.split(" ").reject(&:empty?)
      # count occurences of every parameter, initial value is 0
      occurences = Hash.new { |_k| 0 }
      params.each do |param|
        k = kernel_param_key(param)
        occurences[k] += 1
      end
      done = false
      params = params.each_with_object([]) do |param, res|
        k = kernel_param_key(param)
        if k != key # not our param
          res << param
        elsif values == "false"
          next # do nothing as we want to remove this param
        elsif occurences[k] == 1 # last parameter with given key
          done = true
          if values == "true"
            res << key
          elsif values != "false"
            Array(values).each do |v|
              res << Builtins.sformat("%1=%2", key, v)
            end
          end
        else
          occurences[k] -= 1
        end
      end
      if !done
        if values == "true"
          params << key
        elsif values != "false"
          Array(values).each do |v|
            params << Builtins.sformat("%1=%2", key, v)
          end
        end
      end
      # bnc#945479 perl-bootloader does not cope well with empty strings
      params.empty? ? '""' : params.join(" ")
    end

    # Rewrite current MBR with /var/lib/YaST2/backup_boot_sectors/%device
    # Warning!!! don't use for bootsectors, 440 bytes of sector are written
    # @param [String] device string device to rewrite MBR to
    # @return [Boolean] true on success
    def restoreMBR(device)
      backup = ::Bootloader::BootRecordBackup.new(device)
      begin
        backup.restore
      rescue ::Bootloader::BootRecordBackup::Missing
        Report.Error("Can't restore MBR. No saved MBR found")
        return false
      end
    end

    # Update the Kernel::vgaType value to the saved one if not defined
    def UpdateInstallationKernelParameters
      saved_params = {}
      if !Stage.initial
        saved_params = Convert.convert(
          SCR.Read(path(".target.ycp"), "/var/lib/YaST2/bootloader.ycp"),
          :from => "any",
          :to   => "map <string, any>"
        )
      end
      if Kernel.GetVgaType == ""
        vgaType = Ops.get_string(saved_params, "vgamode", "")
        Kernel.SetVgaType(vgaType) if !vgaType.nil? && vgaType != ""
      end
      if !Stage.initial
        Kernel.SetCmdLine(
          Ops.get_string(saved_params, "installation_kernel_params", "")
        )
      else
        if SCR.Read(path(".etc.install_inf.NoPCMCIA")) == "1"
          Kernel.SetCmdLine(Ops.add(Kernel.GetCmdLine, " NOPCMCIA"))
        end
      end

      nil
    end

    # Check if the bootloader can be installed at all with current configuration
    # @return [Boolean] true if it can
    def BootloaderInstallable
      return true if Mode.config
      if Arch.i386 || Arch.x86_64
        # the only relevant is the partition holding the /boot filesystem
        DetectDisks()
        Builtins.y2milestone(
          "Boot partition device: %1",
          BootStorage.BootPartitionDevice
        )
        dev = Storage.GetDiskPartition(BootStorage.BootPartitionDevice)
        Builtins.y2milestone("Disk info: %1", dev)
        # MD, but not mirroring is OK
        # FIXME: type detection by name deprecated
        if Ops.get_string(dev, "disk", "") == "/dev/md"
          tm = Storage.GetTargetMap
          md = Ops.get_map(tm, "/dev/md", {})
          parts = Ops.get_list(md, "partitions", [])
          info = {}
          Builtins.foreach(parts) do |p|
            if Ops.get_string(p, "device", "") ==
                BootStorage.BootPartitionDevice
              info = deep_copy(p)
            end
          end
          if Builtins.tolower(Ops.get_string(info, "raid_type", "")) != "raid1"
            Builtins.y2milestone(
              "Cannot install bootloader on RAID (not mirror)"
            )
            return false
          end

        # EVMS
        # FIXME: type detection by name deprecated
        elsif Builtins.search(getBootPartition, "/dev/evms/") == 0
          Builtins.y2milestone("Cannot install bootloader on EVMS")
          return false
        end

        return true
      else
        return true
      end
    end

    # Check if the bootloader can be installed on partition boot record
    # @return [Boolean] true if it can
    def PartitionInstallable
      lt = getLoaderType(false)

      return true if lt != "grub2" && lt != "grub2-efi"

      if Arch.i386 || Arch.x86_64
        DetectDisks()
        dev = Storage.GetDiskPartition(BootStorage.BootPartitionDevice)
        Builtins.y2milestone("Disk info: %1", dev)
        if Ops.get_string(dev, "disk", "") == "/dev/md"
          return false
        elsif !Ops.is_integer?(Ops.get(dev, "nr", 0))
          return false
        end
      end

      true
    end

    # Function return boot device it means
    # return boot partition or root partition if boot partition deosn't exist
    # function return "" if boot partition or root partition is not defined (autoyast)
    # @return [String] name of boot device (partition)

    def getBootPartition
      boot_device = ""
      if BootStorage.BootPartitionDevice != ""
        boot_device = BootStorage.BootPartitionDevice
      elsif BootStorage.RootPartitionDevice != ""
        boot_device = BootStorage.RootPartitionDevice
      end

      boot_device
    end

    # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
    # Function select boot device - disk
    #
    # @return [String] name of boot device - disk

  end
end
