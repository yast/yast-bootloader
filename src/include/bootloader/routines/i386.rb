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

      # Info about keeping MBR contents

      # Keep the MBR contents?
      @_keep_mbr = nil
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
  end
end
