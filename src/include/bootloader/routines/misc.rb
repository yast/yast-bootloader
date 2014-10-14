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

require "bootloader/device_mapping"

module Yast
  module BootloaderRoutinesMiscInclude
    def initialize_bootloader_routines_misc(include_target)
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
        return mode == :summary ?
          # summary string
          _("Do not install any boot loader") :
          # combo box item
          _("Do Not Install Any Boot Loader")
      end
      if bootloader == "default"
        return mode == :summary ?
          # summary string
          _("Install the default boot loader") :
          # combo box item
          _("Install Default Boot Loader")
      end
      fallback_name = mode == :summary ?
        # summary string
        _("Boot loader") :
        # combo box item
        _("Boot Loader")
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
      globals_set = deep_copy(globals_set)
      if Arch.ppc
        by_mount = :id
      else
        by_mount = Storage.GetDefaultMountBy
      end

      return globals_set if by_mount == :label

      globals_set["boot_custom"] &&=
        ::Bootloader::DeviceMapping.to_kernel_device(globals_set["boot_custom"])

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
      if @globals["boot_boot"] == "true"
        ret << BootStorage.BootPartitionDevice
      end
      if @globals["boot_root"] == "true"
        ret << BootStorage.RootPartitionDevice
      end
      if @globals["boot_mbr"] == "true"
        ret << @mbrDisk
      end
      if @globals["boot_extended"] == "true"
        ret << BootStorage.ExtendedPartitionDevice
      end
      if @globals["boot_custom"]
        ret << @globals["boot_custom"]
      end
      return ret unless ret.empty?
      # FIXME: find out what the best value is here: nil, [] or ["/dev/null"]
      ["/dev/null"]
    end

    # get kernel parameter from kernel command line
    # @param [String] line string original line
    # @param [String] key string parameter key
    # @return [String] value, "false" if not present,
    #   "true" if present key without value
    def getKernelParamFromLine(line, key)
      # FIXME this doesn't work with quotes and spaces
      res = "false"
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
      # FIXME this doesn't work with quotes and spaces
      params = line.split(" ").reject(&:empty?)
      # count occurences of every parameter, initial value is 0
      occurences = Hash.new { |k| 0 }
      params.each do |param|
        k = kernel_param_key(param)
        occurences[k] += 1
      end
      done = false
      params = params.reduce([]) do |res, param|
        k = kernel_param_key(param)
        if k != key # not our param
          res << param
        elsif value == "false"
          # do nothing as we want to remove this param
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
        res
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

    # Get partition which should be activated if doing it during bl inst.
    # @param [String] boot_partition string the partition holding /boot subtree
    # @param [String] loader_device string the device to install bootloader to
    # @return a map $[ "dev" : string, "mbr": string, "num": any]
    #  containing device (eg. "/dev/hda4"), disk (eg. "/dev/hda") and
    #  partition number (eg. 4)
    def getPartitionToActivate(boot_partition, loader_device)
      p_dev = Storage.GetDiskPartition(loader_device)
      num = p_dev["nr"].to_i
      mbr_dev = Ops.get_string(p_dev, "disk", "")

      # if bootloader is installed to /dev/md*
      # FIXME: use ::storage to detect md devices, not by name!
      if Builtins.substring(loader_device, 0, 7) == "/dev/md"
        md = Md2Partitions(loader_device)
        min = 256 # max. is 255; 256 means "no bios_id found"
        device = ""
        Builtins.foreach(md) do |d, id|
          if Ops.less_than(id, min)
            min = id
            device = d
          end
        end
        if device != ""
          p_dev2 = Storage.GetDiskPartition(device)
          p_dev2["nr"].to_i
          mbr_dev = Ops.get_string(p_dev2, "disk", "")
        end
      # if bootloader in MBR, activate /boot partition
      # (partiall fix of #20637)
      elsif num == 0
        p_dev = Storage.GetDiskPartition(boot_partition)
        num = p_dev["nr"].to_i
        mbr_dev = Ops.get_string(p_dev, "disk", "")

        if Ops.greater_than(Builtins.size(Md2Partitions(boot_partition)), 1)
          Builtins.foreach(Md2Partitions(boot_partition)) do |k, v|
            if Builtins.search(k, loader_device) == 0
              p_dev = Storage.GetDiskPartition(k)
              num = p_dev["nr"].to_i
              mbr_dev = Ops.get_string(p_dev, "disk", "")
            end
          end
        end
      end
      if num != 0
        if Ops.greater_than(num, 4)
          Builtins.y2milestone("Bootloader partition type is logical")
          tm = Storage.GetTargetMap
          partitions = Ops.get_list(tm, [mbr_dev, "partitions"], [])
          Builtins.foreach(partitions) do |p|
            if Ops.get(p, "type") == :extended
              num = Ops.get_integer(p, "nr", num)
              Builtins.y2milestone("Using extended partition %1 instead", num)
            end
          end
        end
      end
      ret = {
        "num" => num,
        "mbr" => mbr_dev,
        "dev" => Storage.GetDeviceName(mbr_dev, num)
      }
      deep_copy(ret)
    end

    # Get a list of partitions to activate if user wants to activate
    # boot partition
    # @return a list of partitions to activate
    def getPartitionsToActivate
      md = {}
      if @loader_device == "mbr_md"
        md = Md2Partitions(BootStorage.BootPartitionDevice)
      else
        md = Md2Partitions(@loader_device)
      end
      partitions = Builtins.maplist(md) { |k, v| k }
      partitions = [@loader_device] if Builtins.size(partitions) == 0
      ret = Builtins.maplist(partitions) do |partition|
        getPartitionToActivate(BootStorage.BootPartitionDevice, partition)
      end
      Builtins.toset(ret)
    end

    # Get the list of MBR disks that should be rewritten by generic code
    # if user wants to do so
    # @return a list of device names to be rewritten
    def getMbrsToRewrite
      ret = [@mbrDisk]
      md = {}
      if @loader_device == "mbr_md"
        md = Md2Partitions(BootStorage.BootPartitionDevice)
      else
        md = Md2Partitions(@loader_device)
      end
      mbrs = Builtins.maplist(md) do |d, b|
        d = Ops.get_string(
          getPartitionToActivate(BootStorage.BootPartitionDevice, d),
          "mbr",
          @mbrDisk
        )
        d
      end
      if Builtins.contains(mbrs, @mbrDisk)
        ret = Convert.convert(
          Builtins.merge(ret, mbrs),
          :from => "list",
          :to   => "list <string>"
        )
      end
      Builtins.toset(ret)
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
      # FIXME move to boot storage
      tm = Storage.GetTargetMap
      ret = {}
      tm.each do |k, v|
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
        Kernel.SetVgaType(vgaType) if vgaType != nil && vgaType != ""
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
        @additional_failsafe_params = SCR.Read(
          path(".etc.install_inf.NoPCMCIA")
        ) == "1" ? " NOPCMCIA " : ""
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

    # bnc#511319 Add information about /etc/sysconfig/bootloader to configuration file.
    # Write option with value and comment to
    # sysconfig file
    #
    # @param boolean true if called from client inst_bootloader
    # @param path to config file (.sysconfig.bootloader)
    # @param [Yast::Path] option (.DEFAULT_APPEND)
    # @param [String] value of otion
    # @param [String] comment of option
    # @return true on success

    def WriteOptionToSysconfig(inst, file_path, option, value, comment)
      ret = false

      if !inst && !FileUtils.Exists("/etc/sysconfig/bootloader")
        Builtins.y2milestone(
          "Skip writting configuration to /etc/sysconfig/bootloader -> file missing"
        )
        return ret
      end
      file_path_option = Builtins.add(file_path, option)
      comment_exist = SCR.Read(Builtins.add(file_path_option, path(".comment"))) == nil

      # write value of option
      ret = SCR.Write(file_path_option, value)

      # write comment of option if it is necessary
      if !comment_exist
        ret = ret &&
          SCR.Write(Builtins.add(file_path_option, path(".comment")), comment)
      end
      SCR.Write(file_path, nil)
      ret
    end

    # bnc#511319 Add information about /etc/sysconfig/bootloader to configuration file.
    # Create /etc/sysconfig/bootloader it is configuration
    # file for bootloader
    #
    # @param boolean true if it is called from client inst_bootlaoder
    # @return [Boolean] true on success

    def CreateBLSysconfigFile(inst)
      if inst
        if !FileUtils.Exists(Ops.add(Installation.destdir, "/etc/sysconfig"))
          WFM.Execute(
            path(".local.mkdir"),
            Ops.add(Installation.destdir, "/etc/sysconfig")
          )
          WFM.Execute(
            path(".local.bash"),
            Builtins.sformat(
              "touch %1/etc/sysconfig/bootloader",
              Installation.destdir
            )
          )
        end
        #string target_sysconfig_path = Installation::destdir + "/etc/sysconfig/bootloader";
        return true
      end
      true
    end

    # FATE #302245 save kernel args etc to /etc/sysconfig/bootloader
    # Function write/update info in /etc/sysconfig/bootloader
    # @param booloean true if it called from inst_bootloader.ycp

    def WriteToSysconf(inst_bootloader)
      lt = getLoaderType(false)
      Builtins.y2milestone("Saving /etc/sysconfig/bootloader for %1", lt)
      # save some sysconfig variables
      # register new agent pointing into the mounted filesystem
      sys_agent = path(".sysconfig.bootloader")

      if inst_bootloader
        sys_agent = Builtins.add(path(".target"), sys_agent)
        target_sysconfig_path = Ops.add(
          Installation.destdir,
          "/etc/sysconfig/bootloader"
        )
        SCR.RegisterAgent(
          sys_agent,
          term(:ag_ini, term(:SysConfigFile, target_sysconfig_path))
        )
      end
      CreateBLSysconfigFile(inst_bootloader)

      comment = ""
      comment = "\n" +
        "## Path:\tSystem/Bootloader\n" +
        "## Description:\tBootloader configuration\n" +
        "## Type:\tlist(grub,grub2,grub2-efi,none)\n" +
        "## Default:\tgrub2\n" +
        "#\n" +
        "# Type of bootloader in use.\n" +
        "# For making the change effect run bootloader configuration tool\n" +
        "# and configure newly selected bootloader\n" +
        "#\n" +
        "#\n"

      WriteOptionToSysconfig(
        inst_bootloader,
        sys_agent,
        path(".LOADER_TYPE"),
        lt,
        comment
      )

      comment = "\n" +
        "## Path:\tSystem/Bootloader\n" +
        "## Description:\tBootloader configuration\n" +
        "## Type:\tyesno\n" +
        "## Default:\t\"no\"\n" +
        "#\n" +
        "# Enable UEFI Secure Boot support\n" +
        "# This setting is only relevant to UEFI which supports UEFI. It won't\n" +
        "# take effect on any other firmware type.\n" +
        "#\n" +
        "#\n"

      sb = getSystemSecureBootStatus(false) ? "yes" : "no"
      WriteOptionToSysconfig(
        inst_bootloader,
        sys_agent,
        path(".SECURE_BOOT"),
        sb,
        comment
      )

      nil
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

      if boot_disk_device != "" && boot_disk_device != nil
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
        ret = Ops.add("ttyS", unit)
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
          unit = getKeyValue(key) if Builtins.search(key, "--unit") != nil
          speed = getKeyValue(key) if Builtins.search(key, "--speed") != nil
          parity = getKeyValue(key) if Builtins.search(key, "--parity") != nil
          word = getKeyValue(key) if Builtins.search(key, "--word") != nil
        end
        # build value
        ret = buildConsoleValue(unit, speed, parity, word)
      end

      ret
    end

    # This function gets bootloader's serial settings from append (bnc#862388)
    def GetSerialFromAppend ()
      append = @globals["append"] || ""
      type = Builtins.regexpsub(append, "^.*console=([[:alpha:]]+)[[:digit:]]*,*[[:digit:]]*[noe]*[[:digit:]]*.*[[:space:]]*.*$", "\\1")
      args = Builtins.regexpsub(append, "^.*console=[[:alpha:]]+([[:digit:]]*,*[[:digit:]]*[noe]*[[:digit:]]*).*[[:space:]]*.*$", "\\1")

      Builtins.y2milestone("BuildSerialFromAppend: %1, %2", type, args)
      return "" if type != "ttyS" || args.empty?

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
       if !word.empty?
         ret << " --word=#{word}"
       end

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

      if Ops.get(@globals, "append") != nil
        updated_append = ""
        if console_value != "" || console_value != nil
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
        Ops.set(@globals, "append", updated_append) if updated_append != nil
      end

      nil
    end
  end
end
