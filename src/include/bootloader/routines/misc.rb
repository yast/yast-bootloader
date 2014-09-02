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



    # Update the text of countdown widget
    # @param [String] bootloader string printable name of used bootloader
    def updateTimeoutPopupForFloppy(bootloader)
      return if Mode.normal

      confirm_boot_msg = Misc.boot_msg
      # data saved to floppy disk
      msg = Builtins.sformat(
        # popup, %1 is bootloader name
        _("The %1 boot sector has been written to the floppy disk."),
        bootloader
      )
      msg = Ops.add(msg, "\n")
      # always hard boot
      # If LILO was written on floppy disk and we need
      # to do a hard reboot (because a different kernel
      # was installed), tell the user to leave the floppy
      # inserted.
      msg = Ops.add(
        msg,
        # popup - continuing
        _("Leave the floppy disk in the drive.")
      )

      if Ops.greater_than(Builtins.size(confirm_boot_msg), 0)
        msg = Ops.add(Ops.add(msg, "\n"), confirm_boot_msg)
      end
      Misc.boot_msg = msg

      nil
    end


    # Function remap globals settings "boot_custom" device name (/dev/sda)
    # or to label (ufo_partition)
    # @param map<string,string> globals
    # @return [Hash{String => String}] globals

    def remapGlobals(globals_set)
      globals_set = deep_copy(globals_set)
      by_mount = nil
      if Arch.ppc
        by_mount = :id
      else
        by_mount = Storage.GetDefaultMountBy
      end

      #by_mount = `id;
      return deep_copy(globals_set) if by_mount == :label

      if Builtins.haskey(globals_set, "boot_custom")
        Ops.set(
          globals_set,
          "boot_custom",
          BootStorage.MountByDev2Dev(Ops.get(globals_set, "boot_custom", ""))
        )
      end

      if Builtins.haskey(globals_set, "boot_chrp_custom")
        Ops.set(
          globals_set,
          "boot_chrp_custom",
          BootStorage.MountByDev2Dev(
            Ops.get(globals_set, "boot_chrp_custom", "")
          )
        )
      end

      if Builtins.haskey(globals_set, "boot_pmac_custom")
        Ops.set(
          globals_set,
          "boot_pmac_custom",
          BootStorage.MountByDev2Dev(
            Ops.get(globals_set, "boot_pmac_custom", "")
          )
        )
      end

      if Builtins.haskey(globals_set, "boot_iseries_custom")
        Ops.set(
          globals_set,
          "boot_iseries_custom",
          BootStorage.MountByDev2Dev(
            Ops.get(globals_set, "boot_iseries_custom", "")
          )
        )
      end

      if Builtins.haskey(globals_set, "boot_prep_custom")
        Ops.set(
          globals_set,
          "boot_prep_custom",
          BootStorage.MountByDev2Dev(
            Ops.get(globals_set, "boot_prep_custom", "")
          )
        )
      end
      deep_copy(globals_set)
    end

    # Function remap "resume" from section (append) to device name (/dev/sda)
    # or to label (ufo_partition)
    #
    # @param map<string,any> sections
    # @param boolean true if convert resume to persistent device name
    # @return [Hash{String => Object}] sections

    def remapResume(append, to_persistent)
      if Builtins.search(append, "resume") != nil &&
          Builtins.search(append, "noresume") == nil
        Builtins.y2milestone("append before remapping resume: %1", append)
        list_append = Builtins.splitstring(append, " ")
        Builtins.y2debug("split append to list list_append: %1", list_append)
        new_append = []

        Builtins.foreach(list_append) do |key|
          if Builtins.search(key, "resume") != nil
            Builtins.y2debug("arg resume from append: %1", key)
            resume_arg = Builtins.splitstring(key, "=")
            dev = Ops.get(resume_arg, 1, "")
            Builtins.y2debug("value of resume: %1", Ops.get(resume_arg, 1, ""))
            if dev != ""
              resume = ""
              # bnc#533782 - after changing filesystem label system doesn't boot
              if to_persistent
                resume = Ops.add("resume=", BootStorage.Dev2MountByDev(dev))
              else
                resume = Ops.add("resume=", BootStorage.MountByDev2Dev(dev))
              end
              Builtins.y2debug("remap resume: %1", resume)
              new_append = Builtins.add(new_append, resume)
            else
              Builtins.y2debug("adding key to new append_list: %1", key)
              new_append = Builtins.add(new_append, key)
            end
          else
            Builtins.y2debug("adding key to new append_list: %1", key)
            new_append = Builtins.add(new_append, key)
          end
        end

        Builtins.y2debug("NEW append list: %1", new_append)
        ret = Builtins.mergestring(new_append, " ")
        Builtins.y2milestone("Append after remaping: %1", ret)
        return ret
      else
        Builtins.y2milestone("Section hasn't resume...")
        return append
      end
    end

    # Function remap section "root" and "resume" to device name (/dev/sda)
    # or to label (ufo_partition)
    # it also prepared measured files for export
    # @param list<map<string,any> > list of sections
    # @return [Array<Hash{String => Object>}] list of sections

    def remapSections(sec)
      sec = deep_copy(sec)
      by_mount = nil
      if Arch.ppc
        by_mount = :id
      else
        by_mount = Storage.GetDefaultMountBy
      end

      #by_mount = `id;
      return deep_copy(sec) if by_mount == :label

      temp_sec = []

      # convert root and resume device names in sections to kernel device names
      temp_sec = Builtins.maplist(@sections) do |s|
        if Ops.get_string(s, "root", "") != ""
          rdev = Ops.get_string(s, "root", "")
          Ops.set(s, "root", BootStorage.MountByDev2Dev(rdev))

          if Ops.get_string(s, "append", "") != ""
            Ops.set(
              s,
              "append",
              remapResume(Ops.get_string(s, "append", ""), false)
            )
          end

          Builtins.y2debug(
            "remapping root: %1 from section to: %2 ",
            rdev,
            Ops.get_string(s, "root", "")
          )
        end
        if Ops.get_string(s, "chainloader", "") != ""
          Ops.set(
            s,
            "chainloader",
            BootStorage.MountByDev2Dev(Ops.get_string(s, "chainloader", ""))
          )
        end
        deep_copy(s)
      end

      deep_copy(temp_sec)
    end

    # returns list difference A \ B (items that are in A and are not in B)
    # @param [Array] a list A
    # @param [Array] b list B
    # @return [Array] see above
    def difflist(a, b)
      a = deep_copy(a)
      b = deep_copy(b)
      Builtins.filter(a) { |e| !Builtins.contains(b, e) }
    end

    # translate filename path (eg. /boot/kernel) to list of device
    #  and relative path
    # @param [String] fullpth string fileststem path (eg. /boot/vmlinuz)
    # @return a list containing device and relative path,
    #  eg. ["/dev/hda1", "/vmlinuz"]
    def splitPath(fullpth)
      mountpoints = Storage.GetMountPoints,
      dev = ""
      mp = ""
      max = 0
      #
      # FIXME: this is broken code, implement a proper prefix match!! see below
      Builtins.foreach(mountpoints) do |k, v|
        if k != "swap" && Builtins.issubstring(fullpth, k) &&
            Ops.greater_than(Builtins.size(k), max)
          max = Builtins.size(k)
          dev = Ops.get_string(v, 0, "")
          mp = k
        end
      end
      return [] if mp == ""

      # FIXME: pth will be wrong for fullpth=='(hd0,1)/boot/vmlinux' !!
      pth = Builtins.substring(fullpth, Builtins.size(mp))
      pth = Ops.add("/", pth) if Builtins.substring(pth, 0, 1) != "/"
      [dev, pth]
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
      return StorageDevices.FloppyDevice if @selected_location == "floppy"
      return "mbr_md" if @selected_location == "mbr_md"
      return "/dev/null" if @selected_location == "none"
      @loader_device
    end

    # Get list of bootloader device names for all selected or specified
    # locations
    # @return [Array] device names
    def GetBootloaderDevices
      ret = []
      if Ops.get(@globals, "boot_boot", "false") == "true"
        ret = Builtins.add(ret, BootStorage.BootPartitionDevice)
      end
      if Ops.get(@globals, "boot_root", "false") == "true"
        ret = Builtins.add(ret, BootStorage.RootPartitionDevice)
      end
      if Ops.get(@globals, "boot_mbr", "false") == "true"
        ret = Builtins.add(ret, @mbrDisk)
      end
      if Builtins.haskey(@globals, "boot_extended") &&
          Ops.get(@globals, "boot_extended", "false") == "true"
        ret = Builtins.add(ret, BootStorage.ExtendedPartitionDevice)
      end
      # FIXME: floppy support is probably obsolete
      if Builtins.haskey(@globals, "boot_floppy") &&
          Ops.get(@globals, "boot_floppy", "false") == "true"
        ret = Builtins.add(ret, StorageDevices.FloppyDevice)
      end
      if Builtins.haskey(@globals, "boot_custom")
        ret = Builtins.add(ret, Ops.get(@globals, "boot_custom", ""))
      end
      return deep_copy(ret) if Ops.greater_than(Builtins.size(ret), 0)
      # FIXME: find out what the best value is here: nil, [] or ["/dev/null"]
      ["/dev/null"]
    end

    # Check if the PBR of the given partition seems to contain a known boot block
    # @param [String] device string partition device to check
    # @return true if the PBR seems to contain a known boot block
    def IsPartitionBootable(device)
      #FIXME this is only for grub and should go to BootGRUB
      # use examineMBR to analyze PBR (partition boot record):
      # examineMBR returns "* stage1" when it finds the signature
      # of some stage1 bootloader
      result = examineMBR(device)
      if result == "grub"
        return true
      else
        return false
      end
    end


    # Check if installation to floppy is performed
    # @return true if installing bootloader to floppy
    def InstallingToFloppy
      ret = false
      # Bug 539774 - bootloader module wants to write to floppy disk although there is none
      return ret if @loader_device == nil || @loader_device == "" # bug #333459 - boot loader editor: propose new configuration
      if @loader_device == StorageDevices.FloppyDevice
        ret = true
      elsif Builtins.contains(BootStorage.getFloppyDevices, @loader_device)
        ret = true
      end
      Builtins.y2milestone("Installing to floppy: %1", ret)
      ret
    end


    # Get the list of particular kernel parameters
    # @param [String] line string the whole kernel command line
    # @return a list of the kernel parameters split each separaterlly
    def ListKernelParamsInLine(line)
      # FIXME this function is really similar to code in Kernel.ycp
      cmdlist = []
      parse_index = 0
      in_quotes = false
      after_backslash = false
      current_param = ""
      while Ops.less_than(parse_index, Builtins.size(line))
        current_char = Builtins.substring(line, parse_index, 1)
        in_quotes = !in_quotes if current_char == "\"" && !after_backslash
        if current_char == " " && !in_quotes
          cmdlist = Builtins.add(cmdlist, current_param)
          current_param = ""
        else
          current_param = Ops.add(current_param, current_char)
        end
        if current_char == "\\"
          after_backslash = true
        else
          after_backslash = false
        end
        parse_index = Ops.add(parse_index, 1)
      end
      cmdlist = Builtins.add(cmdlist, current_param)
      cmdlist = Builtins.maplist(cmdlist) do |c|
        if Builtins.regexpmatch(c, "^[^=]+=")
          c = Builtins.regexpsub(c, "^([^=]+)=", "\\1")
        end
        c
      end
      deep_copy(cmdlist)
    end

    # get kernel parameter from kernel command line
    # @param [String] line string original line
    # @param [String] key string parameter key
    # @return [String] value, "false" if not present,
    #   "true" if present key without value
    def getKernelParamFromLine(line, key)
      # FIXME this doesn't work with quotes and spaces
      res = "false"
      params = Builtins.splitstring(line, " ")
      params = Builtins.filter(params) { |p| p != "" }
      Builtins.foreach(params) do |p|
        l = Builtins.filter(Builtins.splitstring(p, "=")) do |e|
          e != " " && e != ""
        end
        res = Ops.get(l, 1, "true") if Ops.get(l, 0, "") == key
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


    #  convert any value to an integer and return 0 for nonsense
    def myToInteger(num_any)
      num_any = deep_copy(num_any)
      return 0 if num_any == nil
      return Convert.to_integer(num_any) if Ops.is_integer?(num_any)
      if Ops.is_string?(num_any)
        return num_any == "" ?
          0 :
          Builtins.tointeger(Convert.to_string(num_any)) == nil ?
            0 :
            Builtins.tointeger(Convert.to_string(num_any))
      end
      0
    end


    # Get partition which should be activated if doing it during bl inst.
    # @param [String] boot_partition string the partition holding /boot subtree
    # @param [String] loader_device string the device to install bootloader to
    # @return a map $[ "dev" : string, "mbr": string, "num": any]
    #  containing device (eg. "/dev/hda4"), disk (eg. "/dev/hda") and
    #  partition number (eg. 4)
    def getPartitionToActivate(boot_partition, loader_device)
      p_dev = Storage.GetDiskPartition(loader_device)
      num = myToInteger(Ops.get(p_dev, "nr"))
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
          num = myToInteger(Ops.get(p_dev2, "nr"))
          mbr_dev = Ops.get_string(p_dev2, "disk", "")
        end
      # if bootloader in MBR, activate /boot partition
      # (partiall fix of #20637)
      elsif num == 0
        p_dev = Storage.GetDiskPartition(boot_partition)
        num = myToInteger(Ops.get(p_dev, "nr"))
        mbr_dev = Ops.get_string(p_dev, "disk", "")

        if Ops.greater_than(Builtins.size(Md2Partitions(boot_partition)), 1)
          Builtins.foreach(Md2Partitions(boot_partition)) do |k, v|
            if Builtins.search(k, loader_device) == 0
              p_dev = Storage.GetDiskPartition(k)
              num = myToInteger(Ops.get(p_dev, "nr"))
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
      device_file = Builtins.mergestring(Builtins.splitstring(device, "/"), "_")
      if Ops.less_or_equal(
          SCR.Read(
            path(".target.size"),
            Builtins.sformat(
              "/var/lib/YaST2/backup_boot_sectors/%1",
              device_file
            )
          ),
          0
        )
        Report.Error("Can't restore MBR. No saved MBR found")
        return false
      end
      # added fix 446 -> 440 for Vista booting problem bnc #396444
      ret = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/bin/dd of=%1 if=/var/lib/YaST2/backup_boot_sectors/%2 bs=440 count=1",
            device,
            device_file
          )
        )
      )
      ret == 0
    end

    # Update kernel parameters if some were added in Kernel module
    # @param [String] orig original kernel parameters or kernel command line
    # @return kernel command line or parameters with added new parameters
    def UpdateKernelParams(orig)
      new = Builtins.splitstring(Kernel.GetCmdLine, " ")
      old = Builtins.splitstring(orig, " ")
      added = Convert.convert(
        difflist(new, Builtins.splitstring(@kernelCmdLine, " ")),
        :from => "list",
        :to   => "list <string>"
      )
      added = Convert.convert(
        difflist(added, old),
        :from => "list",
        :to   => "list <string>"
      )
      old = Convert.convert(
        Builtins.merge(old, added),
        :from => "list",
        :to   => "list <string>"
      )
      if Stage.initial
        showopts = false
        apic = false
        showopts = true if Builtins.contains(old, "showopts")
        apic = true if Builtins.contains(old, "apic")
        old = Builtins.filter(old) { |o| o != "apic" && o != "showopts" }
        old = Builtins.add(old, "showopts") if showopts
        old = Builtins.add(old, "apic") if apic
      end
      Builtins.mergestring(old, " ")
    end


    # Get map of swap partitions
    # @return a map where key is partition name and value its size
    def getSwapPartitions
      #FIXME use cache of storage map
      tm = Storage.GetTargetMap
      installation = Mode.installation
      ret = {}
      Builtins.foreach(tm) do |k, v|
        cyl_size = Ops.get_integer(v, "cyl_size", 0)
        partitions = Ops.get_list(v, "partitions", [])
        partitions = Builtins.filter(partitions) do |p|
          Ops.get_string(p, "mount", "") == "swap" &&
            !Ops.get_boolean(p, "delete", false)
        end
        Builtins.foreach(partitions) do |s|
          # bnc#577127 - Encrypted swap is not properly set up as resume device
          dev = ""
          if Ops.get_string(s, "crypt_device", "") != nil &&
              Ops.get_string(s, "crypt_device", "") != ""
            dev = Ops.get_string(s, "crypt_device", "")
          else
            dev = Ops.get_string(s, "device", "")
          end
          Ops.set(
            ret,
            dev,
            Ops.multiply(Ops.get_integer(s, ["region", 1], 0), cyl_size)
          )
        end
      end
      Builtins.y2milestone("Available swap partitions: %1", ret)
      deep_copy(ret)
    end



    # Check if device is MBR of a disk
    # @param [String] device string device to check
    # @return [Boolean] true if is MBR
    def IsMbr(device)
      if Builtins.regexpmatch(
          device,
          "^/dev/[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]+$"
        )
        return true
      end
      if Builtins.regexpmatch(
          device,
          "^/dev/[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ]+/.*d[0-9]+$"
        )
        return true
      end
      false
    end

    # Add '(MBR)' to the disk description if it is a MBR of some partition
    # @param [String] descr string disk description
    # @param [String] device string disk device
    # @return [String] updated description
    def AddMbrToDescription(descr, device)
      IsMbr(device) ? Builtins.sformat("%1 (MBR)", descr) : descr
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

    # Update graphical bootloader to contain help text of current language
    # And make the selected installation language default
    # @return [Boolean] true on success
    def UpdateGfxMenuContents
      GfxMenu.UpdateGfxMenuContents(getLoaderType(false))
    end

    # Check if memtest86 is present
    # @return [Boolean] true if memtest86 section is to be proposed
    def MemtestPresent
      !Builtins.contains(@removed_sections, "memtest") &&
        (Mode.test || Mode.normal && Pkg.IsProvided("memtest86+") ||
          !Mode.normal && Pkg.IsSelected("memtest86+"))
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
        # LVM
        elsif !Ops.is_integer?(Ops.get(dev, "nr", 0))
          lt = getLoaderType(false)
          if lt != "grub2" && lt != "grub2-efi"
            Builtins.y2milestone("Cannot install bootloader %1 on LVM", lt)
            return false
          end
        else
          tm = Storage.GetTargetMap
          dm = Ops.get_map(tm, Ops.get_string(dev, "disk", ""), {})
          parts = Ops.get_list(dm, "partitions", [])
          info = {}
          Builtins.foreach(parts) do |p|
            if Ops.get_string(p, "device", "") ==
                BootStorage.BootPartitionDevice
              info = deep_copy(p)
            end
          end

          if Ops.get(info, "used_fs") == :btrfs
            lt = getLoaderType(false)
            if lt != "grub2" && lt != "grub2-efi"
              Builtins.y2milestone("Cannot install bootloader %1 on btrfs", lt)
              return false
            end
          end
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


    # Function return absolute value of arg
    #
    # @param [Fixnum] value
    # @return [Fixnum] absolute value

    def abs(value)
      if Ops.less_than(value, 0)
        return Ops.multiply(value, -1)
      else
        return value
      end
    end

    # bnc #440125 - default boot section with failsafe args
    # Compare append from default linux section with append from
    # BootCommon::sections
    #
    # @return [Boolean] true if appends are similar
    def compareAppends(default_append, section_append)
      deuce = 0
      # delete white space on the beginning of string
      default_append = String.CutBlanks(default_append)
      section_append = String.CutBlanks(section_append)
      # check valid append for section
      #FIXME JR I think this is not true, append is valid even if it contain only one letter '3' which mean go to runlevel 3
      return false if Ops.less_than(Builtins.size(section_append), 3)

      # check size of default append with section append
      # if the size is same return true (same appends)
      Builtins.y2milestone(
        "Size of default append: \"%1\" and compared section append: \"%2\"",
        Builtins.size(default_append),
        Builtins.size(section_append)
      )
      if Builtins.size(default_append) == Builtins.size(section_append)
        return true
      end

      default_list = Builtins.splitstring(default_append, " ")
      section_list = Builtins.splitstring(section_append, " ")

      size_default_list = Builtins.size(default_list)
      size_section_list = Builtins.size(section_list)

      relative_deuce = abs(Ops.subtract(size_section_list, size_default_list))

      # check number of append args
      # if different between number of args is more than 3 args return false

      Builtins.y2milestone(
        "No. default args: %1 no. compared section args: %2",
        size_default_list,
        size_section_list
      )
      return false if Ops.greater_or_equal(relative_deuce, 3)

      # check args by keywords from section append to default append

      Builtins.y2milestone("default_append: %1", default_append)
      Builtins.y2milestone("section_list: %1", section_list)
      Builtins.foreach(section_list) do |key|
        if Builtins.search(key, "resume=") != nil
          tmp = Builtins.splitstring(key, "=")
          key = BootStorage.Dev2MountByDev(Ops.get(tmp, 1, ""))
        end
        if Builtins.search(default_append, key) != nil
          deuce = Ops.add(deuce, 1)
        else
          deuce = Ops.subtract(deuce, 1)
        end
      end

      # if there exist more than 3 different args return false
      # else append seem to be similar -> true
      Builtins.y2milestone(
        "No. deuces of default append with compared append: %1",
        deuce
      )
      if Ops.greater_or_equal(abs(Ops.subtract(size_default_list, deuce)), 3)
        return false
      else
        return true
      end
    end



    # bnc #440125 - default boot section with failsafe args
    # Check if default boot name is linux
    #
    # @param string default boot name
    # @return [Boolean] true if boot name is linux
    def isDefaultBootSectioLinux(default_boot)
      ret = false
      Builtins.foreach(@sections) do |s|
        if Ops.get_string(s, "name", "") == default_boot
          ret = true if Ops.get_string(s, "original_name", "") == "linux"
          raise Break
        end
      end
      if ret
        Builtins.y2milestone("Boot section: \"%1\" is linux", default_boot)
      else
        Builtins.y2warning("Boot section: \"%1\" is NOT linux", default_boot)
      end
      ret
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
    # bnc #578545 - kdump misconfigures crashkernel parameter for Xen
    # Check if default_append includes crashkernel arg
    #
    # @param string defaul_append
    # @return [String] defaul_append without crashkernel

    def deleteCrashkernelFromAppend(append)
      Builtins.y2milestone("Original append: %1", append)
      list_append = Builtins.splitstring(append, " ")

      if Ops.greater_than(Builtins.size(list_append), 0)
        list_append = Builtins.filter(list_append) do |key|
          if Builtins.search(key, "crashkernel") == nil
            next true
          else
            next false
          end
        end
      end
      ret = Builtins.mergestring(list_append, " ")
      Builtins.y2milestone("Filtered append: %1", ret)
      ret
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

    # FATE #303548 - Grub: limit device.map to devices detected by BIOS Int 13
    # Function select boot device - disk
    #
    # @return [String] name of boot device - disk


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
    # - add key console with value to section type image and xen

    def HandleConsole
      console_value = getConsoleValue

      # list of idexes from sections where is image or xen
      list_index = []
      # counter
      index = -1
      Builtins.foreach(@sections) do |section|
        index = Ops.add(index, 1)
        if Ops.get_string(section, "type", "") == "image" ||
            Builtins.search(Ops.get_string(section, "type", ""), "xen") != nil
          list_index = Builtins.add(list_index, index)
        end
      end

      # add key console with value
      if Ops.greater_than(Builtins.size(list_index), 0)
        Builtins.foreach(list_index) do |idx|
          Ops.set(@sections, [idx, "__changed"], true)
          if Ops.get(@sections, [idx, "append"]) != nil
            updated_append = ""
            if console_value != "" || console_value != nil
              updated_append = UpdateSerialConsole(
                Ops.get_string(@sections, [idx, "append"], ""),
                console_value
              )
            else
              updated_append = UpdateSerialConsole(
                Ops.get_string(@sections, [idx, "append"], ""),
                ""
              )
            end
            if updated_append != nil
              Ops.set(@sections, [idx, "append"], updated_append)
            end
          end
          Builtins.y2debug(
            "Added/Removed console for section: %1",
            Ops.get(@sections, idx, {})
          )
        end
      end

      nil
    end


    # FATE #110038: Serial console
    # Add console arg for kernel if there is defined serial console
    # - add key console with value to section type image and xen

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

    # bnc #450153 - support for installation kernel from add-on
    # fucntion call client from add-on and update proposal for
    # yast2-bootloader. -> availabe edit kernel args for kernel
    # from add-on
    #
    # @return [Boolean] - true on success
    def UpdateProposalFromClient
      ret = true
      client_file = "kernel_bl_proposal"
      if !Arch.i386 && !Arch.x86_64
        Builtins.y2milestone(
          "Unsuported architecture... for adding SLERT addon"
        )
        return ret
      end

      if WFM.ClientExists(client_file)
        Builtins.y2milestone("Client: %1 was found", client_file)
        WFM.CallFunction(client_file, [])
      else
        Builtins.y2milestone(
          "File %1 doesn't exist - proposal will not be updated",
          client_file
        )
      end

      ret
    end
  end
end
