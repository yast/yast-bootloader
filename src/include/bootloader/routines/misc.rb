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
      if !Arch.ppc
        return globals_set if Storage.GetDefaultMountBy == :label
      end

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
      ret << @globals["boot_custom"] if @globals["boot_custom"]
      Builtins.y2warning("Empty bootloader devices. Globals #{@globals.inspect}") if ret.empty?

      ret
    end

    # get kernel parameter from kernel command line
    # @param [String] line string original line
    # @param [String] key string parameter key
    # @return [String] value, "false" if not present,
    #   "true" if present key without value
    def getKernelParamFromLine(line, key)
      # FIXME: this doesn't work with quotes and spaces
      res = "false"
      # we can get nil if params is not yet proposed, so return not there (bnc#902397)
      return res unless line
      params = line.split(" ").reject(&:empty?)
      params.each do |p|
        l = p.split("=")
        res = l[1] || "true" if l[0] == key
      end
      res
    end

    def kernel_param_key(value)
      value.split("=").first
    end

    # set kernel parameter to GRUB command line
    # @param [String] line string original line
    # @param [String] key string parameter key
    # @param [String] value string value, "false" to remove key,
    #   "true" to add key without value
    # @return [String] new kernel command line
    def setKernelParamToLine(line, key, value)
      line ||= ""
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
        elsif value == "false"
          next # do nothing as we want to remove this param
        elsif occurences[k] == 1 # last parameter with given key
          done = true
          if value == "true"
            res << key
          elsif value != "false"
            res << Builtins.sformat("%1=%2", key, value)
          end
        else
          occurences[k] -= 1
          res << param
        end
      end
      if !done
        if value == "true"
          params << key
        elsif value != "false"
          params << Builtins.sformat("%1=%2", key, value)
        end
      end
      params.join(" ")
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

    # Get map of swap partitions
    # @return a map where key is partition name and value its size
    def getSwapPartitions
      # FIXME: move to boot storage
      tm = Storage.GetTargetMap
      ret = {}
      tm.each_value do |v|
        cyl_size = v["cyl_size"] || 0
        partitions = v["partitions"] || []
        partitions = partitions.select do |p|
          p["mount"] == "swap" && !p["delete"]
        end
        partitions.each do |s|
          # bnc#577127 - Encrypted swap is not properly set up as resume device
          if s["crypt_device"] && !s["crypt_device"].empty?
            dev = s["crypt_device"]
          else
            dev = s["device"]
          end
          ret[dev] = Ops.get_integer(s, ["region", 1], 0) * cyl_size
        end
      end
      Builtins.y2milestone("Available swap partitions: %1", ret)
      ret
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

    # Get additional kernel parameters
    # @return additional kernel parameters
    def GetAdditionalFailsafeParams
      if Stage.initial
        nopcmcia = SCR.Read(path(".etc.install_inf.NoPCMCIA")) == "1"
        @additional_failsafe_params =  nopcmcia ? " NOPCMCIA " : ""
      else
        saved_params = Convert.convert(
          SCR.Read(path(".target.ycp"), "/var/lib/YaST2/bootloader.ycp"),
          :from => "any",
          :to   => "map <string, any>"
        )
        @additional_failsafe_params = Ops.get_string(
          saved_params,
          "additional_failsafe_params",
          ""
        )
      end
      @additional_failsafe_params
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

    def getBootDisk
      boot_device = getBootPartition

      if boot_device == ""
        Builtins.y2milestone(
          "BootPartitionDevice and RootPartitionDevice are empty"
        )
        return boot_device
      end
      p_dev = Storage.GetDiskPartition(boot_device)

      boot_disk_device = Ops.get_string(p_dev, "disk", "")

      if boot_disk_device != "" && !boot_disk_device.nil?
        Builtins.y2milestone("Boot device - disk: %1", boot_disk_device)
        return boot_disk_device
      end

      Builtins.y2milestone("Finding boot disk failed!")
      ""
    end

    # FATE #110038: Serial console
    # Function build value for console from:
    # @param [String] unit no of console
    # @param [String] speed
    # @param [String] parity (n,o,e)
    # @param [String] word (8)
    # @return [String] value of console for kernel append
    def buildConsoleValue(unit, speed, parity, word)
      ret = ""
      if unit != "" && speed != ""
        # add number of serial console
        if Arch.aarch64
          ret = Ops.add("ttyAMA", unit)
        else
          ret = Ops.add("ttyS", unit)
        end
        # add speed
        ret = Ops.add(Ops.add(ret, ","), speed)
        if parity != ""
          # add parity
          case parity
          when "no"
            ret = Ops.add(ret, "n")
          when "odd"
            ret = Ops.add(ret, "o")
          when "even"
            ret = Ops.add(ret, "e")
          else
            ret = Ops.add(ret, "n")
          end

          # add word
          ret = Ops.add(ret, word) if word != ""
        end
        Builtins.y2milestone("console value for kernel: %1", ret)
      else
        Builtins.y2error(
          "Wrong values unit: %1 , speed: %2 , parity: %3 , word: %4",
          unit,
          speed,
          parity,
          word
        )
      end
      ret
    end

    # FATE #110038: Serial console
    # Function parse string key (e.g. --speed=9600)
    # and return value of key
    # @param [String] key e.g. --unit=0
    # @return [String] value of key

    def getKeyValue(key)
      ret = ""
      value = []
      if key != ""
        value = Builtins.splitstring(key, "=")
        ret = Ops.get(value, 1, "") if Ops.get(value, 1, "") != ""
      end

      Builtins.y2debug("parse: %1 and return value: %2", key, ret)
      ret
    end

    # FATE #110038: Serial console
    # Function check value from globals (serial and terminal)
    # after that build value of console append for kernel if it is possible
    # @return [String] value of console for kernel append

    def getConsoleValue
      ret = ""
      if Ops.get(@globals, "serial", "") != "" &&
          Ops.get(@globals, "terminal", "") != ""
        list_serial = Builtins.splitstring(Ops.get(@globals, "serial", ""), " ")
        Builtins.y2milestone("list of serial args: %1", list_serial)
        unit = ""
        speed = ""
        parity = ""
        word = ""
        Builtins.foreach(list_serial) do |key|
          unit = getKeyValue(key) unless Builtins.search(key, "--unit").nil?
          speed = getKeyValue(key) unless Builtins.search(key, "--speed").nil?
          parity = getKeyValue(key) unless Builtins.search(key, "--parity").nil?
          word = getKeyValue(key) unless Builtins.search(key, "--word").nil?
        end
        # build value
        ret = buildConsoleValue(unit, speed, parity, word)
      end

      ret
    end

    # This function gets bootloader's serial settings from append (bnc#862388)
    def GetSerialFromAppend
      append = @globals["append"] || ""
      type = Builtins.regexpsub(append, "^.*console=([[:alpha:]]+)[[:digit:]]*,*[[:digit:]]*[noe]*[[:digit:]]*.*[[:space:]]*.*$", "\\1")
      args = Builtins.regexpsub(append, "^.*console=[[:alpha:]]+([[:digit:]]*,*[[:digit:]]*[noe]*[[:digit:]]*).*[[:space:]]*.*$", "\\1")

      Builtins.y2milestone("BuildSerialFromAppend: %1, %2", type, args)
      return "" if (type != "ttyS" && type != "ttyAMA") || args.empty?

      unit = Builtins.regexpsub(args, "([[:digit:]]+),*[[:digit:]]*[noe]*[[:digit:]]*", "\\1")
      return ""  if unit == ""

      ret = "serial --unit=#{unit}"

      speed = Builtins.regexpsub(args, "[[:digit:]]+,*([[:digit:]]*)[noe]*[[:digit:]]*", "\\1")
      speed = "9600" if speed.empty?
      ret << " --speed=#{speed}"

      parity = Builtins.regexpsub(args, "[[:digit:]]+,*[[:digit:]]*([noe]*)[[:digit:]]*", "\\1")
      case parity
      when "n"
        ret << " --parity=no"
      when "o"
        ret << " --parity=odd"
      when "e"
        ret << " --parity=even"
      when ""
        # no parity, do nothing
      else
        raise "unknown parity flag #{parity}"
      end

      word = Builtins.regexpsub(args, "[[:digit:]]+,*[[:digit:]]*[noe]*([[:digit:]]*)", "\\1")
      ret << " --word=#{word}" unless word.empty?

      ret
    end

    # FATE #110038: Serial console
    # Add console arg for kernel if there is defined serial console

    def HandleConsole2
      if @globals["terminal"] != "serial"
        # if bootloader is not set to serial console, we should leave the
        # kernel append as is to allow it's serial console be enabled
        # for debugging output and so on (bnc#866710)
        return
      end

      if !@globals["serial"] || @globals["serial"].empty?
        # http://www.gnu.org/software/grub/manual/grub.html#serial
        # https://www.kernel.org/doc/Documentation/serial-console.txt
        # default settings is the same, we should at least tell kernel the
        # port (aka unit) to use and grub2 defaults to 0.
        # speed is also required by builkConsoleValue
        @globals["serial"] = "serial --unit=0 --speed=9600"
      end

      console_value = getConsoleValue

      if !Ops.get(@globals, "append").nil?
        updated_append = ""
        if console_value != "" || !console_value.nil?
          updated_append = UpdateSerialConsole(
            Ops.get(@globals, "append", ""),
            console_value
          )
        else
          updated_append = UpdateSerialConsole(
            Ops.get(@globals, "append", ""),
            ""
          )
        end
        Ops.set(@globals, "append", updated_append) if !updated_append.nil?
      end

      nil
    end
  end
end
