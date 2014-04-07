# encoding: utf-8

# File:
#      modules/BootPOWERLILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for POWERLILO configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class BootPOWERLILOClass < Module
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Arch"
      Yast.import "BootArch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Installation"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Storage"

      # include ppc specific help messages
      Yast.include self, "bootloader/ppc/helps.rb"

      # read my dialogs
      Yast.include self, "bootloader/routines/popups.rb"




      # This whole code is a big mess. To have a solution at all I included and
      # adapted copies of the code from the old BootPPC.ycp, from common code in
      # lilolike.ycp and others.
      #
      # od - February and March 2006

      # partition number for the bootloader (either 41PReP boot or Apple_HFS)
      # start with disabled value and let the partition scanner find a match.
      @prep_boot_partition = ""

      # map available of 41 PReP partitions, used on iSeries and CHRP
      @prep_boot_partitions = []

      # map available HFS partitions, used on PMac
      @pmac_boot_partitions = []

      # PReP boot partitions that were proposed by partitioner to install BL
      @install_prep_boot_partitions = []

      # saved ID of the base installation source
      @base_source = -1

      # iSeries specific global settings

      # current board attribs
      @prep_only_active = true
      @prep_only_iseries_vd = true
      @prep_only_primary = true
      @prep_same_disk_as_root = true
      @table_items = []
      @boot_device = ""

      @board_type = nil


      Yast.include self, "bootloader/ppc/dialogs.rb"
      BootPOWERLILO()
    end

    # Update list of 41 PReP boot partitions
    # @return [Boolean] true if list changed, false otherwise
    def updatePrepBootPartitions
      Builtins.y2milestone(
        "Detecting PReP partitions: prep_only_active: %1, prep_only_iseries_vd: %2, prep_only_primary: %3",
        @prep_only_active,
        @prep_only_iseries_vd,
        @prep_only_primary
      )
      targetMap = Storage.GetTargetMap
      Builtins.y2milestone("TargetMap: %1", targetMap)
      old_prep_boot_partitions = deep_copy(@prep_boot_partitions)
      old_install_prep_boot_partitions = deep_copy(
        @install_prep_boot_partitions
      )
      @prep_boot_partitions = []
      @install_prep_boot_partitions = []
      Builtins.y2milestone(
        "old prep_boot_partitions %1",
        old_prep_boot_partitions
      )

      Builtins.foreach(targetMap) do |dname, ddata|
        partitions = Ops.get_list(ddata, "partitions", [])
        Builtins.y2milestone("Partitions: %1", partitions)
        partitions = Builtins.filter(partitions) do |p|
          !Ops.get_boolean(p, "delete", false) &&
            Ops.is_integer?(Ops.get(p, "fsid")) &&
            # both partition types 0x41 and FAT16 can be handled by PPC lilo
            (Ops.get(p, "fsid") == 65 || Ops.get(p, "fsid") == 6) &&
            !Builtins.contains(
              [:lvm, :evms, :sw_raid],
              Ops.get_symbol(p, "type", :primary)
            )
        end
        Builtins.y2milestone("Filtered existing partitions: %1", partitions)
        # prep_only_iseries_vd means: use only partitions on /dev/iseries/vd*
        partitions = Builtins.filter(partitions) do |p|
          Builtins.regexpmatch(
            Ops.get_string(p, "device", ""),
            "/dev/iseries/vd.*"
          )
        end if @prep_only_iseries_vd
        partitions = Builtins.filter(partitions) do |p|
          Ops.get_symbol(p, "type", :primary) == :primary
        end if @prep_only_primary
        Builtins.y2milestone("Finally filtered partitions: %1", partitions)
        @prep_boot_partitions = Convert.convert(
          Builtins.merge(@prep_boot_partitions, Builtins.maplist(partitions) do |p|
            Ops.get_string(p, "device", "")
          end),
          :from => "list",
          :to   => "list <string>"
        )
        partitions = Builtins.filter(partitions) do |p|
          Ops.get_boolean(p, "prep_install", false)
        end
        Builtins.y2milestone(
          "Finally filtered recommended partitions: %1",
          partitions
        )
        @install_prep_boot_partitions = Convert.convert(
          Builtins.merge(
            @install_prep_boot_partitions,
            Builtins.maplist(partitions) { |p| Ops.get_string(p, "device", "") }
          ),
          :from => "list",
          :to   => "list <string>"
        )
      end
      @prep_boot_partitions = Builtins.filter(@prep_boot_partitions) do |p|
        p != ""
      end
      @prep_boot_partitions = Builtins.sort(@prep_boot_partitions)
      Builtins.y2milestone(
        "Detected PReP partitions: %1",
        @prep_boot_partitions
      )
      Builtins.y2milestone(
        "Proposed PReP partitions: %1",
        @install_prep_boot_partitions
      )

      if old_prep_boot_partitions == @prep_boot_partitions &&
          old_install_prep_boot_partitions == @install_prep_boot_partitions
        Builtins.y2milestone("PReP Partitions unchanged")
        return false
      else
        Builtins.y2milestone("PReP Partitions changed")
        return true
      end
    end

    # Select PReP boot partition to propose
    # Changes internal variables.
    def choosePrepBootPartition
      Builtins.y2milestone("Resetting selected PReP boot partition")
      root_disks = []
      if Storage.CheckForLvmRootFs
        tm = Storage.GetTargetMap
        vg = ""
        Builtins.foreach(tm) do |dev, info|
          if Ops.get_symbol(info, "type", :CT_UNKNOWN) == :CT_LVM
            volumes = Ops.get_list(info, "partitions", [])
            Builtins.foreach(volumes) do |v|
              if Ops.get_string(v, "mount", "") == "/"
                vg = Ops.get_string(info, "name", "")
                Builtins.y2milestone("Volume group of root FS: %1", vg)
              end
            end
          end
        end
        Builtins.foreach(tm) do |dev, info|
          partitions = Ops.get_list(info, "partitions", [])
          Builtins.foreach(partitions) do |p|
            if Ops.get_string(p, "used_by_device", "") == Ops.add("/dev/", vg)
              root_disks = Builtins.add(root_disks, dev)
            end
          end
        end
        Builtins.y2milestone("Disks holding LVM with root fs: %1", root_disks)
      else
        root_disks = [
          Ops.get_string(
            Storage.GetDiskPartition(BootStorage.RootPartitionDevice),
            "disk",
            ""
          )
        ]
      end

      @prep_boot_partition = ""
      # First take the partitions that Storage:: hinted us to take, then
      # consider the other prep_boot_partitions
      @prep_boot_partitions = Convert.convert(
        Builtins.merge(@install_prep_boot_partitions, @prep_boot_partitions),
        :from => "list",
        :to   => "list <string>"
      )
      # in the combined list, look for "usable" partitions:
      #	- if we require the boot partition to be on the same disk as
      #	  the root partition ("prep_same_disk_as_root"), select the
      #	  first prep partition from that disk
      #	- otherwise take the first prep partition in the list
      Builtins.foreach(@prep_boot_partitions) do |partition|
        if @prep_boot_partition == ""
          usable = true
          if @prep_same_disk_as_root
            part_split = Storage.GetDiskPartition(partition)
            part_disk = Ops.get_string(part_split, "disk", "")
            usable = false if !Builtins.contains(root_disks, part_disk)
          end
          @prep_boot_partition = partition if usable
        end
      end

      # For CHRP lilo can handle PReP partition on other disks now
      # If all above fails, take the first one then ...
      if @prep_boot_partition == "" && getBoardType == "chrp"
        @prep_boot_partition = Ops.get(@prep_boot_partitions, 0, "")
      end

      Builtins.y2milestone(
        "Selected PReP boot partition: %1",
        @prep_boot_partition
      )
      BootCommon.activate = @prep_boot_partition != ""
      Builtins.y2milestone("Install bootloader: %1", BootCommon.activate)

      nil
    end


    # Initialize attributes of the board type
    def PRePInit
      Builtins.y2milestone("Initializing PReP attributes")
      @prep_only_active = true
      @prep_only_iseries_vd = false
      @prep_only_primary = true
      @prep_same_disk_as_root = false
      @table_items = ["__prep_location"]

      nil
    end


    # Initialize attributes of the board type
    def CHRPInit
      Builtins.y2milestone("Initializing CHRP attributes")
      @prep_only_active = true
      @prep_only_iseries_vd = false
      @prep_only_primary = true
      # On CHRP, if there is no bootable partition on the disk containing
      # "/", there is CHRP-specific code in choosePrepBootPartition that
      # takes the first prep partition in the system.
      @prep_same_disk_as_root = true
      @table_items = ["__chrp_location", "__set_default_of"]

      nil
    end


    # Helper function that executes a command with the shell, appending
    # stdout and stderr to a logfile. On error, it writes log entries to the
    # yast2 log.
    # @param [String] command string command to execute
    # @param [String] logfile string logfile for the commands output
    # @return [Boolean] true on success
    def iSeriesExecute(command, logfile)
      command = Ops.add(Ops.add(Ops.add(command, " >>"), logfile), " 2>&1")
      command_ret = Convert.to_integer(
        SCR.Execute(path(".target.bash"), command)
      )
      if command_ret != 0
        Builtins.y2error(
          "Execution of command failed: %1, error code: %2",
          command,
          command_ret
        )
        log = Convert.to_string(SCR.Read(path(".target.string"), logfile))
        Builtins.y2error("stderr and stdout of the command: %1", log)
        return false
      end
      true
    end


    # Install the board-type-specific part of bootloader
    # @return [Boolean] true on success
    def iSeriesWrite
      return true if !BootCommon.activate

      # during installation (fresh or update), always install the ISERIES64
      # file into slot A as a "rescue system"
      if Stage.initial
        command = ""
        my_log = "/var/log/YaST2/y2log_bootloader_iseries_slot_a"

        # bnc #409927 VUL-0: yast2: slideshow not checked cryptographically
        src_filename = Pkg.SourceProvideDigestedFile(
          @base_source,
          1,
          "/ISERIES64",
          false
        )

        if @base_source == -1 || src_filename == nil
          Builtins.y2milestone(
            "Cannot write rescue kernel to slot A, base source not found"
          )
          return false
        end

        rescue_bootbinary = Ops.add(
          Convert.to_string(SCR.Read(path(".target.tmpdir"))),
          "/rescue_bootbinary"
        )

        tg_rescue_bootbinary = Ops.add(Installation.destdir, rescue_bootbinary)
        Builtins.y2milestone(
          "Copying %1 to %2",
          src_filename,
          tg_rescue_bootbinary
        )
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat("/bin/cp %1 %2", src_filename, tg_rescue_bootbinary)
        )

        Builtins.y2milestone("start writing rescue kernel to slot A ...")
        command = Ops.add(
          Ops.add("time dd if=", rescue_bootbinary),
          " of=/proc/iSeries/mf/A/vmlinux bs=64k"
        )
        return false if !iSeriesExecute(command, my_log)

        if !iSeriesExecute(
            "dd if=/dev/zero of=/proc/iSeries/mf/A/cmdline bs=255 count=1",
            my_log
          )
          return false
        end

        # NOTE: on SLES10, the "root=" parameter is not handled by the
        # initrd in the ISERIES64 file. The initrd just boots up to a
        # shell.
        SCR.Execute(
          path(".target.bash"),
          "echo -en 'start_shell manual=1\\0' > /proc/iSeries/mf/A/cmdline"
        )
        Builtins.y2milestone("done writing rescue kernel to slot A.")
      end

      true
    end


    # Initialize attributes of the board type
    def iSeriesInit
      Builtins.y2milestone("Initializing iSeries attributes")
      @prep_only_active = true
      @prep_only_iseries_vd = true
      @prep_only_primary = true
      @prep_same_disk_as_root = false
      @table_items = ["__iseries_location"]

      nil
    end


    # misc. functions

    def initBoardType
      if Arch.board_iseries
        @board_type = "iseries"
      elsif Arch.board_prep
        @board_type = "prep"
      elsif Arch.board_chrp
        @board_type = "chrp"
      elsif Arch.board_mac_new
        @board_type = "pmac"
      elsif Arch.board_mac_old
        @board_type = "pmac"
      else
        @board_type = "unknown"
      end
      Builtins.y2milestone("setting board type to: %1", @board_type)

      nil
    end

    def getBoardType
      initBoardType if @board_type == nil
      @board_type
    end

    # Initialize the attribute of currently used board type
    def currentBoardInit
      if getBoardType == "iseries"
        iSeriesInit
      elsif getBoardType == "prep"
        PRePInit()
      elsif getBoardType == "chrp"
        CHRPInit()
      end 
      # TODO other boards

      nil
    end


    # Create section for bootable image
    # @param [String] title   string	the section name to create (untranslated)
    # @return	    [Hash]		describes the section
    def CreateImageSection(title)
      ret = BootCommon.CreateLinuxSection(title)
      #Do not use translated names, as we are happy if it work with kernel device
      Ops.set(ret, "root", BootStorage.RootPartitionDevice)
      # bnc #217443
      Ops.set(ret, "optional", "true")
      #do not use translated name FIXME this should be filtered out
      Ops.set(ret, "name", title)
      deep_copy(ret)
    end

    # Choose a boot partition on pmac
    # type == Apple_HFS|Apple_Bootstrap && size < 20 cyl
    # @return [String] device name of pmac boot partition
    def GoodPmacBootPartition
      Builtins.y2milestone("Detecting pmac boot partition")
      targetMap = Storage.GetTargetMap
      Builtins.y2milestone("TargetMap: %1", targetMap)

      boot_partitions = []
      selected_boot_partition = ""

      Builtins.foreach(targetMap) do |dname, ddata|
        partitions = Ops.get_list(ddata, "partitions", [])
        Builtins.y2milestone("Partitions: %1", partitions)
        # does this device contain the root partition?
        hasrootdev = Builtins.find(partitions) do |p|
          !Ops.get_boolean(p, "delete", false) &&
            Ops.get_string(p, "device", "") == BootStorage.RootPartitionDevice &&
            !Builtins.contains(
              [:lvm, :evms, :sw_raid],
              Ops.get_symbol(p, "type", :primary)
            )
        end != nil
        # find possible boot partitions
        partitions = Builtins.filter(partitions) do |p|
          !Ops.get_boolean(p, "delete", false) &&
            Ops.is_integer?(Ops.get(p, "fsid")) &&
            # both partition types Apple_Bootstrap and Apple_HFS can be
            # handled by PPC lilo; yast2-storage maps both to fsid 258
            Ops.get(p, "fsid") == 258 &&
            !Builtins.contains(
              [:lvm, :evms, :sw_raid],
              Ops.get_symbol(p, "type", :primary)
            )
        end
        Builtins.y2milestone("Filtered existing partitions: %1", partitions)
        # bug #459860 - no boot partition found during fresh install
        # find the smallest partition
        max_size = 1000000000
        iter = -1
        min_position = -1
        Builtins.foreach(partitions) do |p|
          iter = Ops.add(iter, 1)
          if Ops.less_than(Ops.get_integer(p, "size_k", 0), max_size)
            min_position = iter
            max_size = Ops.get_integer(p, "size_k", 0)
          end
        end
        # if any partition was found
        if Ops.greater_than(min_position, -1)
          tmp_partitions = []
          partition = Ops.get(partitions, min_position, {})
          if Ops.less_than(Ops.get_integer(partition, "size_k", 0), 160650)
            Builtins.y2milestone(
              "Partition smaller than 160650k: %1",
              partition
            )
          else
            Builtins.y2warning(
              "Partition is not smaller than 160650k: %1",
              partition
            )
          end
          tmp_partitions = Builtins.add(tmp_partitions, partition)
          partitions = deep_copy(tmp_partitions)
        end
        Builtins.y2milestone("Filtered existing partitions: %1", partitions)
        # found a boot partition on the same device as the root partition?
        if hasrootdev && Ops.greater_than(Builtins.size(partitions), 0) &&
            selected_boot_partition == ""
          Builtins.y2milestone(
            "Selected pmac boot partition %1 on device with root partition %2",
            Ops.get_string(partitions, [0, "device"], ""),
            BootStorage.RootPartitionDevice
          )
          selected_boot_partition = Ops.get_string(
            partitions,
            [0, "device"],
            ""
          )
        end
        # collect found boot partitions
        boot_partitions = Convert.convert(
          Builtins.merge(boot_partitions, Builtins.maplist(partitions) do |p|
            Ops.get_string(p, "device", "")
          end),
          :from => "list",
          :to   => "list <string>"
        )
      end
      Builtins.y2milestone("Detected pmac boot partitions: %1", boot_partitions)
      @pmac_boot_partitions = deep_copy(boot_partitions)
      if selected_boot_partition == ""
        selected_boot_partition = Ops.get(boot_partitions, 0, "")
      end
      Builtins.y2milestone(
        "Selected pmac boot partition: %1",
        selected_boot_partition
      )
      selected_boot_partition
    end

    # Propose the location of the root device on disk and the boot device (if
    # any), according to the subarchitecture.
    # Results are stored in global variables.
    #
    def LocationProposal
      BootCommon.DetectDisks
      # del_parts is used by FixSections() in lilolike.ycp (imported by BootCommon.ycp)
      BootCommon.del_parts = BootStorage.getPartitionList(:deleted, "ppc")

      if BootCommon.DisksChanged
        Builtins.y2milestone("Reconfiguring locations")
        BootCommon.DetectDisks
      end

      if updatePrepBootPartitions || @prep_boot_partition == ""
        # TODO warning to user
        choosePrepBootPartition
      end

      case getBoardType
        when "chrp"
          BootStorage.BootPartitionDevice = @prep_boot_partition
        when "prep"
          BootStorage.BootPartitionDevice = @prep_boot_partition
        when "iseries"
          BootStorage.BootPartitionDevice = @prep_boot_partition
        when "pmac"
          BootStorage.BootPartitionDevice = GoodPmacBootPartition()
        else
          Builtins.y2error("Unknown ppc architecture")
      end

      # These need to be set, for POWERLILO probably only to interface with
      # autoyast, others base subsequent decisions on this.
      # See ConfigureLocation() in lilolike.ycp.
      #
      # Mini-discussion: If autoyast is mainly used to clone configs, the
      # loader_device and repl_mbr interface is enough, because loader_device
      # simply contains the name of the device (partition, disk MBR, RAID
      # device) to use for the bootloader.
      # But if autoyast some day is used to transport configurations to less
      # similar machines and setups, or to specify some sort of generic setup
      # with special settings that will work on most machines, it may (or may
      # not) be helpful to be able to specify boot_* variables in the autoyast
      # file. This may apply better to the boot_* variables in BootGRUB.ycp
      # though.
      # FIXME: what about loader_location (aka selected_location internally)?
      BootCommon.loader_device = BootStorage.BootPartitionDevice
      BootCommon.activate = true
      Builtins.y2milestone("Boot partition is %1", BootCommon.loader_device)

      nil
    end

    # Propose sections to bootloader menu
    # modifies internal sreuctures
    def CreateSections
      linux = CreateImageSection("linux")

      # FIXME: create an 'other' section for MACs to boot MacOS

      BootCommon.sections = [linux]

      nil
    end

    # Propose global options of bootloader
    # modifies internal structures
    def CreateGlobals
      BootCommon.globals = {
        "activate" => "true",
        "default"  => Ops.get_string(BootCommon.sections, [0, "name"], ""),
        "timeout"  => "8"
      }

      boot_map = {}

      Builtins.y2milestone(
        "RootPartDevice is %1",
        BootStorage.RootPartitionDevice
      )
      case getBoardType
        when "chrp"
          boot_map = { "boot_chrp_custom" => BootStorage.BootPartitionDevice }
        when "prep"
          boot_map = { "boot_prep_custom" => BootStorage.BootPartitionDevice }
        when "pmac"
          boot_map = { "boot_pmac_custom" => BootStorage.BootPartitionDevice }
        when "iseries"
          boot_map = {
            "boot_slot" => "B",
            # FIXME: what file should be used here?
            "boot_file" => "/tmp/suse_linux_image"
          }

          # If we have an empty BootPartitionDevice on iseries, this means:
          # do not boot from BootPartitionDevice but from some other place.
          # Do not pass down to perl-Bootloader, lilo fails on an empty "boot =" line.
          if BootStorage.BootPartitionDevice != nil &&
              BootStorage.BootPartitionDevice != ""
            Ops.set(
              boot_map,
              "boot_iseries_custom",
              BootStorage.BootPartitionDevice
            )
          end
        else
          Builtins.y2error("Unknown ppc architecture")
      end

      # Finally merge results into "globals": new values replace old ones
      BootCommon.globals = Convert.convert(
        Builtins.union(BootCommon.globals, boot_map),
        :from => "map",
        :to   => "map <string, string>"
      )

      nil
    end

    # Save the ID of the base installation source
    # modifies internal variable
    def SaveInstSourceId
      @base_source = -1

      # Find the source ID of the base product:
      # list all products
      products = Pkg.ResolvableProperties("", :product, "")
      Builtins.y2milestone("products: %1", products)
      # filter products to be installed
      products = Builtins.filter(products) do |p|
        Ops.get_integer(p, "source", -1) != -1
      end
      # get base products
      base_products = Builtins.filter(products) do |p|
        Ops.get_string(p, "category", "") == "base"
      end
      base_products = deep_copy(products) if Builtins.size(base_products) == 0 # just to be safe in case of a bug...
      sources = Builtins.maplist(base_products) do |p|
        Ops.get_integer(p, "source", -1)
      end
      Builtins.y2milestone(
        "remaining products: %1, sources: %2",
        products,
        sources
      )
      sources = Builtins.sort(sources)
      @base_source = Ops.get(sources, 0, -1)

      Builtins.y2milestone("Base source: %1", @base_source)

      nil
    end

    # bnc #439674 Autoyast install of Cell blades fails to install bootloader
    # The function update global settings for bootloader
    # if there is used autoyast The basic problem is that there is missing
    # boot_* , timeout etc.
    # If there missing necessary information they will be added
    #
    def UpdateGlobalsInAutoInst
      if !Builtins.haskey(BootCommon.globals, "timeout")
        Ops.set(BootCommon.globals, "timeout", "8")
      end

      if !Builtins.haskey(BootCommon.globals, "activate")
        Ops.set(BootCommon.globals, "activate", "true")
      end

      # if there missing boot_* -> then propose it
      if !Builtins.haskey(BootCommon.globals, "boot_chrp_custom") &&
          !Builtins.haskey(BootCommon.globals, "boot_prep_custom") &&
          !Builtins.haskey(BootCommon.globals, "boot_pmac_custom") &&
          !Builtins.haskey(BootCommon.globals, "boot_iseries_custom")
        arch = getBoardType
        case arch
          when "prep"
            Ops.set(
              BootCommon.globals,
              "boot_prep_custom",
              BootStorage.BootPartitionDevice
            )
          when "pmac"
            Ops.set(
              BootCommon.globals,
              "boot_pmac_custom",
              BootStorage.BootPartitionDevice
            )
          when "iseries"
            Ops.set(BootCommon.globals, "boot_slot", "B")
            Ops.set(BootCommon.globals, "boot_file", "/tmp/suse_linux_image")

            if BootStorage.BootPartitionDevice != nil &&
                BootStorage.BootPartitionDevice != ""
              Ops.set(
                BootCommon.globals,
                "boot_iseries_custom",
                BootStorage.BootPartitionDevice
              )
            end
          else
            Ops.set(
              BootCommon.globals,
              "boot_chrp_custom",
              BootStorage.BootPartitionDevice
            )
        end
      end

      nil
    end

    # general functions

    # Propose bootloader settings
    def Propose
      Builtins.y2debug(
        "Started propose: Glob: %1, Sec: %2",
        BootCommon.globals,
        BootCommon.sections
      )

      # Need to remember inst source ID now to get the ISERIES64 file from the
      # inst source later on (see Bug #165497, Comment #16). This won't work
      # later during inst_finish, so we need to do it earlier -- only the
      # proposal is a possible place.
      SaveInstSourceId()

      # FIXME: make modern code out of these conditionals
      #        - comments
      #        - simplify
      #        - check validity
      initial_propose = true
      if BootCommon.was_proposed
        # FIXME: autoyast settings are simply Import()ed and was_proposed is
        # set to true. The settings for the current board still need to be
        # initialized though. We do this every time the bootloader proposal is
        # called, because it also does not harm (results for the board
        # detection are cached both in Arch.ycp and in our variable
        # board_type.) To fix: make the "where does the information come
        # from", when, more clear and obvious (in the code and/or in docs).
        currentBoardInit if Mode.autoinst
        initial_propose = false
      else
        currentBoardInit
      end
      Builtins.y2milestone("board type is: %1", @board_type)

      # Get root and boot partition (if any)
      LocationProposal()

      if BootCommon.sections == nil || Builtins.size(BootCommon.sections) == 0
        CreateSections() # make an initial proposal for at least one section
        BootCommon.kernelCmdLine = Kernel.GetCmdLine
      else
        if Mode.autoinst
          Builtins.y2debug("Nothing to do in AI mode if sections exist")
          # bnc #439674 Autoyast install of Cell blades fails to install bootloader
          UpdateGlobalsInAutoInst()
        else
          BootCommon.FixSections(fun_ref(method(:CreateSections), "void ()"))
        end
      end

      if BootCommon.globals == nil ||
          # consider globals empty even if lines_cache_id is present
          Builtins.size(Builtins.filter(BootCommon.globals) do |key, v|
            key != "lines_cache_id"
          end) == 0
        CreateGlobals()
      else
        if Mode.autoinst
          Builtins.y2debug("Nothing to do in AI mode if globals are defined")
        else
          BootCommon.FixGlobals
        end
      end

      Builtins.y2milestone("Proposed sections: %1", BootCommon.sections)
      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals)

      nil
    end



    # Export bootloader settings to a map
    # @return bootloader settings
    def Export
      exp = {
        "global"   => BootCommon.remapGlobals(BootCommon.globals),
        "sections" => BootCommon.remapSections(BootCommon.sections),
        "activate" => BootCommon.activate
      }
      deep_copy(exp)
    end


    # Import settings from a map
    # @param [Hash] settings map of bootloader settings
    # @return [Boolean] true on success
    def Import(settings)
      settings = deep_copy(settings)
      BootCommon.globals = Ops.get_map(settings, "global", {})
      BootCommon.sections = Ops.get_list(settings, "sections", [])
      BootCommon.activate = Ops.get_boolean(settings, "activate", false)
      true
    end


    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "ppc")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread

      ret = BootCommon.Read(false, avoid_reading_device_map)
      Builtins.y2milestone(":: Read globals: %1", BootCommon.globals)

      #importMetaData();

      ret
    end


    # Reset bootloader settings
    def Reset(init)
      # Reset global variables to default values
      @prep_boot_partition = ""
      @prep_boot_partitions = []
      @install_prep_boot_partitions = []
      BootCommon.Reset(init)

      nil
    end


    # Save all bootloader configuration files to the cache of the PlugLib
    # PlugLib must be initialized properly !!!
    # @param [Boolean] clean boolean true if settings should be cleaned up (checking their
    #  correctness, supposing all files are on the disk
    # @param [Boolean] init boolean true to init the library
    # @param [Boolean] flush boolean true to flush settings to the disk
    # @return [Boolean] true if success
    def Save(clean, init, flush)
      ret = true

      # FIXME: this is currently a copy from BootCommon::Save
      if clean
        BootCommon.RemoveUnexistentSections("", "")
        BootCommon.UpdateAppend
      end

      # check if there is selected "none" bootloader
      bl = BootCommon.getLoaderType(false)

      if bl == "none"
        BootCommon.InitializeLibrary(init, bl)
        return true
      end

      if !BootCommon.InitializeLibrary(init, "ppc")
        # send current disk/partition information to perl-Bootloader
        BootCommon.SetDiskInfo
      end

      # convert
      my_globals = Builtins.mapmap(BootCommon.globals) do |k, v|
        if k == "stage1_dev" || Builtins.regexpmatch(k, "^boot_.*custom$")
          next { k => BootStorage.Dev2MountByDev(v) }
        else
          next { k => v }
        end
      end

      # FIXME: remove all mountpoints of type 'boot/boot' through some Storage::<func>

      # FIXME: set one mountpoint 'boot/boot' for every boot target means all
      # partitions in 'boot_<arch>_custom' and 'clone' (chrp)

      # ret = ret && BootCommon::SetDeviceMap (device_mapping);

      # bnc #450506 root=kernelname in lilo.conf after upgrade
      BootCommon.sections = BootCommon.remapSections(BootCommon.sections)

      ret = ret && BootCommon.SetSections(BootCommon.sections)
      ret = ret && BootCommon.SetGlobal(my_globals)
      ret = ret && BootCommon.CommitSettings if flush

      #importMetaData();

      BootCommon.WriteToSysconf(false)
      ret
    end


    # Display bootloader summary
    # @return a list of summary lines
    def Summary
      result = []

      # FIXME:
      #	- evaluate and use the text from iSeriesSummary(), PRePSummary() and
      #	  CHRPSummary()
      #  - add the cases for mac_old and mac_new (see BootPPC::Summary())

      # summary text, %1 is bootloader name
      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Boot loader type: %1"),
          BootCommon.getLoaderName(BootCommon.getLoaderType(false), :summary)
        )
      )

      # summary text for boot loader locations, sum up all locations to one string
      boot_loader_locations = Builtins.mergestring(
        Builtins.filter(Builtins.maplist(BootCommon.global_options) do |key, value|
          Builtins.substring(key, 0, 5) == "boot_" ?
            Ops.get(BootCommon.globals, key, "") :
            ""
        end) { |bll| bll != "" },
        ", "
      )
      result = Builtins.add(
        result,
        Builtins.sformat(_("Location: %1"), boot_loader_locations)
      )

      sects = []
      Builtins.foreach(BootCommon.sections) do |s|
        title = Ops.get_string(s, "name", "")
        # section name "suffix" for default section
        _def = title == Ops.get(BootCommon.globals, "default", "") ?
          _(" (default)") :
          ""
        sects = Builtins.add(
          sects,
          String.EscapeTags(Builtins.sformat("+ %1%2", title, _def))
        )
      end
      # summary text. %1 is list of bootloader sections
      result = Builtins.add(
        result,
        Builtins.sformat(
          _("Sections:<br>%1"),
          Builtins.mergestring(sects, "<br>")
        )
      )

      # FIXME: does the following code make any sense for ppc? (see also #163387)
      # It seems not. (We do not do this, cf. jplack.) Keeping the code cadaver
      # around until finally ready for removal.
      # if (BootCommon::loader_device == "/dev/null")
      #    // summary text
      #    result = add (result,
      #		_("Do not install boot loader; just create configuration files"));
      deep_copy(result)
    end


    # Update read settings to new version of configuration files
    def Update
      # Firstly update sections of bootloader configuration and modify internal
      # structures as needed. This means right now:
      #
      # - no change of "resume=" parameter in append entry, not used on ppc yet
      # - delete console= parameters as console autodetection now works

      # This function has been copied from lilolike.ycp::UpdateSections and
      # adapted to conform with the image parameter
      # BootPOWERLILO.ycp/perl-Bootloader uses. Some unneeded code has been
      # removed.
      # FIXME: SLES9 -> SLES10 update: check loader_type = lilo in
      # /etc/sysconfig/bootloader

      # take current sections as starting point
      updated_sections = deep_copy(BootCommon.sections)
      linux_resume_added = false

      default_sect = CreateImageSection("linux")
      default_name = Ops.get_string(default_sect, "name", "")

      # assumption is that all of the following section names ar "good" names
      # meaning that we will return a valid section description from
      # CreateImageSection for them.
      sections_to_recreate = ["linux"]

      updated_sections = Builtins.maplist(updated_sections) do |s|
        name = Ops.get_string(s, "name", "")
        oname = Ops.get_string(s, "original_name", name)
        # if we find a section that looks like it has been initially proposed
        # from the installer, replace with the actual "good" proposal
        if Builtins.contains(sections_to_recreate, oname)
          sections_to_recreate = Builtins.filter(sections_to_recreate) do |this_name|
            this_name != oname
          end
          # check for a new global default if oname != name
          if name == Ops.get(BootCommon.globals, "default", "")
            # we assume that the new name produced by CreateImageSection
            # will be oname
            Ops.set(BootCommon.globals, "default", oname)
          end
          next CreateImageSection(oname)
        end
        # else adjust the entries of the found section according to some
        # fancy rules
        Builtins.foreach(["image", "initrd"]) do |key|
          value = Ops.get_string(s, key, "")
          # FIXME: check whether this is code for update from SLES8?
          #        then we would delete it.
          if Builtins.regexpmatch(value, '^.*\.shipped.*$')
            value = Builtins.regexpsub(value, '^(.*)\.shipped(.*)$', "\\1\\2")
          elsif Builtins.regexpmatch(value, '^.*\.suse.*$')
            value = Builtins.regexpsub(value, '^(.*)\.suse(.*)$', "\\1\\2")
          end
          Ops.set(s, key, value)
        end

        # handle the append line
        append = Ops.get_string(s, "append", "")
        # FIXME: how should we handle root= entries in append= lines?

        # add additional kernel parameters to the end of the append entry
        # of special image section 'linux'
        #
        if oname == "linux"
          Builtins.foreach(BootCommon.ListAdditionalKernelParams) do |o|
            append = BootCommon.setKernelParamToLine(append, o, "false")
          end
          append = Ops.add(
            Ops.add(append, " "),
            BootCommon.GetAdditionalKernelParams
          )

          if BootCommon.getKernelParamFromLine(append, "splash") == "false"
            append = BootCommon.setKernelParamToLine(append, "splash", "silent")
          end
        end
        # remove console= entries from kernel parameters, console auto
        # detection now works. For special sections take what's given on boot
        # command line
        console = "false" # false means delete to 'setKernelParamToLine'
        if Builtins.contains(BootCommon.update_section_types, oname)
          console = BootCommon.getKernelParamFromLine(
            Kernel.GetCmdLine,
            "console"
          )
        end
        append = BootCommon.setKernelParamToLine(append, "console", console)
        # finally append entry is written back
        if append != ""
          Ops.set(s, "append", append)
        else
          s = Builtins.remove(s, "append")
        end
        deep_copy(s)
      end

      # if there was no original section matching the sections we want to
      # recreate, so do prepend or append newly created sections to the list of
      # updated sections
      Builtins.foreach(sections_to_recreate) do |section_name|
        new_section = CreateImageSection(section_name)
        if section_name == "linux"
          updated_sections = Builtins.prepend(updated_sections, new_section)
        else
          updated_sections = Builtins.add(updated_sections, new_section)
        end
      end

      BootCommon.sections = deep_copy(updated_sections)
      Builtins.y2milestone("finished updating sections: %1", updated_sections)
      # End of UpdateSections ();

      # Secondly update global settings of bootloader configuration:
      #
      # - delete console= parameters as console autodetection now works

      # remove console= entries from globals, console auto detection now works
      if Builtins.haskey(BootCommon.globals, "append")
        append = Ops.get(BootCommon.globals, "append", "")
        append = BootCommon.setKernelParamToLine(append, "console", "false")
        if append != ""
          Ops.set(BootCommon.globals, "append", append)
        else
          BootCommon.globals = Builtins.remove(BootCommon.globals, "append")
        end
      end

      nil
    end

    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      iSeriesWrite if getBoardType == "iseries"

      ret = BootCommon.UpdateBootloader

      ret = ret && BootCommon.InitializeBootloader
      ret = false if ret == nil
      ret
    end


    def Dialogs
      # PPC definitly needs other text modules
      { "loader" => fun_ref(method(:PPCDetailsDialog), "symbol ()") }
    end

    # Set section to boot on next reboot
    # @param [String] section string section to boot
    # @return [Boolean] true on success
    def FlagOnetimeBoot(section)
      result = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("/sbin/lilo -R \"%1\"", section)
        )
      )
      Builtins.y2milestone("lilo returned %1", result)
      Ops.get_integer(result, "exit", -1) == 0
    end

    def ppc_section_types
      return ["image", "other"] if Arch.board_iseries

      ["image"]
    end

    # Return map of provided functions
    # @return [Hash] map of functions (eg. $["write":BootPOWERLILO::Write])
    def GetFunctions
      {
        "export"          => fun_ref(method(:Export), "map ()"),
        "import"          => fun_ref(method(:Import), "boolean (map)"),
        "read"            => fun_ref(
          method(:Read),
          "boolean (boolean, boolean)"
        ),
        "reset"           => fun_ref(method(:Reset), "void (boolean)"),
        "propose"         => fun_ref(method(:Propose), "void ()"),
        "save"            => fun_ref(
          method(:Save),
          "boolean (boolean, boolean, boolean)"
        ),
        "summary"         => fun_ref(method(:Summary), "list <string> ()"),
        "update"          => fun_ref(method(:Update), "void ()"),
        "write"           => fun_ref(method(:Write), "boolean ()"),
        "widgets"         => fun_ref(
          method(:ppcWidgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs"         => fun_ref(
          method(:Dialogs),
          "map <string, symbol ()> ()"
        ),
        "section_types"   => fun_ref(
          method(:ppc_section_types),
          "list <string> ()"
        ),
        "flagonetimeboot" => fun_ref(
          method(:FlagOnetimeBoot),
          "boolean (string)"
        )
      }
    end

    # Initializer of PowerLILO bootloader
    def Initializer
      Builtins.y2milestone("Called PowerLILO initializer")
      BootCommon.current_bootloader_attribs = {
        "propose"            => true,
        "read"               => true,
        "scratch"            => true,
        "bootloader_on_disk" => true
      }

      BootCommon.InitializeLibrary(false, "ppc")

      nil
    end

    # Constructor
    def BootPOWERLILO
      Ops.set(
        BootCommon.bootloader_attribs,
        "ppc",
        {
          "required_packages" => ["lilo"],
          "loader_name"       => "ppc",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :variable => :ppc_help_messages, :type => "map <string, string>"
    publish :variable => :ppc_descriptions, :type => "map <string, string>"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :variable => :prep_boot_partition, :type => "string"
    publish :variable => :prep_boot_partitions, :type => "list <string>"
    publish :variable => :pmac_boot_partitions, :type => "list <string>"
    publish :variable => :install_prep_boot_partitions, :type => "list <string>"
    publish :variable => :base_source, :type => "integer"
    publish :variable => :prep_only_active, :type => "boolean"
    publish :variable => :prep_only_iseries_vd, :type => "boolean"
    publish :variable => :prep_only_primary, :type => "boolean"
    publish :variable => :prep_same_disk_as_root, :type => "boolean"
    publish :variable => :table_items, :type => "list"
    publish :variable => :boot_device, :type => "string"
    publish :function => :getBoardType, :type => "string ()"
    publish :function => :currentBoardInit, :type => "void ()"
    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :function => :ppcWidgets, :type => "map <string, map <string, any>> ()"
    publish :function => :iSeriesWrite, :type => "boolean ()"
    publish :function => :iSeriesInit, :type => "void ()"
    publish :function => :initBoardType, :type => "void ()"
    publish :function => :CreateImageSection, :type => "map <string, any> (string)"
    publish :function => :LocationProposal, :type => "void ()"
    publish :function => :CreateSections, :type => "void ()"
    publish :function => :CreateGlobals, :type => "void ()"
    publish :function => :SaveInstSourceId, :type => "void ()"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Export, :type => "map ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Save, :type => "boolean (boolean, boolean, boolean)"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :FlagOnetimeBoot, :type => "boolean (string)"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootPOWERLILO, :type => "void ()"
  end

  BootPOWERLILO = BootPOWERLILOClass.new
  BootPOWERLILO.main
end
