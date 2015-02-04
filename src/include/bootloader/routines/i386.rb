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
  module BootloaderRoutinesI386Include
    def initialize_bootloader_routines_i386(_include_target)
      textdomain "bootloader"

      # general MBR reading cache

      # The last disk that was checked for the sequence
      @_old_mbr_disk = nil

      # Contents of the last read MBR
      @_old_mbr = nil

      # info about ThinkPad

      # Does MBR contain special thinkpadd stuff?
      @_thinkpad_mbr = nil

      # The last disk that was checked for the sequence
      @_old_thinkpad_disk = nil

      # Info about keeping MBR contents

      # Keep the MBR contents?
      @_keep_mbr = nil

      # Sequence specific for IBM ThinkPad laptops, see bug 86762
      @thinkpad_seq = "50e46124108ae0e461241038e074f8e2f458c332edb80103ba8000cd13c3be05068a04240cc0e802c3"
    end

    # Get the contents of the MBR of a disk
    # @param [String] disk string the disk to be checked
    # @return strign the contents of the MBR of the disk in hexa form
    def GetMBRContents(disk)
      if @_old_mbr.nil? || disk != @_old_mbr_disk
        @_old_mbr_disk = disk
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("dd if=%1 bs=512 count=1 | od -v -t x1 -", disk)
          )
        )
        if Ops.get_integer(out, "exit", 0) != 0
          Builtins.y2error("Reading MBR contents failed")
          return nil
        end
        mbr = Ops.get_string(out, "stdout", "")
        mbrl = Builtins.splitstring(mbr, "\n")
        mbrl = Builtins.maplist(mbrl) do |s|
          l = Builtins.splitstring(s, " ")
          Ops.set(l, 0, "")
          Builtins.mergestring(l, "")
        end
        mbr = Builtins.mergestring(mbrl, "")
        Builtins.y2debug("MBR contents: %1", mbr)
        @_old_mbr = mbr
      end
      @_old_mbr
    end

    # Does MBR of the disk contain special IBM ThinkPad stuff?
    # @param [String] disk string the disk to be checked
    # @return [Boolean] true if it is MBR
    def ThinkPadMBR(disk)
      if @_thinkpad_mbr.nil? || disk != @_old_thinkpad_disk
        @_old_thinkpad_disk = disk
        mbr = GetMBRContents(disk)
        x02 = Builtins.tointeger(Ops.add("0x", Builtins.substring(mbr, 4, 2)))
        x03 = Builtins.tointeger(Ops.add("0x", Builtins.substring(mbr, 6, 2)))
        x0e = Builtins.substring(mbr, 28, 2)
        x0f = Builtins.substring(mbr, 30, 2)
        Builtins.y2debug("Data: %1 %2 %3 %4", x02, x03, x0e, x0f)
        @_thinkpad_mbr = Ops.less_or_equal(2, x02) &&
          Ops.less_or_equal(x02, Builtins.tointeger("0x63")) &&
          Ops.less_or_equal(2, x03) &&
          Ops.less_or_equal(x03, Builtins.tointeger("0x63")) &&
          Builtins.tolower(x0e) == "4e" &&
          Builtins.tolower(x0f) == "50"
      end
      Builtins.y2milestone(
        "MBR of %1 contains ThinkPad sequence: %2",
        disk,
        @_thinkpad_mbr
      )
      @_thinkpad_mbr
    end

    # Do updates of MBR after the bootloader is installed
    # @return [Boolean] true on success
    def PostUpdateMBR
      ret = true
      if ThinkPadMBR(@mbrDisk)
        if @loader_device != @mbrDisk
          command = Builtins.sformat("/usr/lib/YaST2/bin/tp_mbr %1", @mbrDisk)
          Builtins.y2milestone("Running command %1", command)
          out = SCR.Execute(path(".target.bash_output"), command)
          Builtins.y2milestone("Command output: %1", out)
          ret = out["exit"].zero?
        end
      end

      ret
    end
  end
end
