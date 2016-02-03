# encoding: utf-8

# File:
#      bootloader/routines/inst_bootloader.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Functions to write "dummy" config files for kernel
#
# Authors:
#      Jozef Uhliarik <juhliarik@suse.cz>
#
#

require "bootloader/bootloader_factory"

module Yast
  class InstBootloaderClient < Client
    def main
      textdomain "bootloader"

      Yast.import "Bootloader"
      # Yast.import "BootCommon"
      Yast.import "Installation"
      Yast.import "GetInstArgs"
      Yast.import "Mode"

      Builtins.y2milestone("starting inst_bootloader")

      if GetInstArgs.going_back # going backwards?
        return :auto # don't execute this once more
      end

      # for upgrade that is from grub2 to grub2 and user do not want
      # any changes, just quit (bnc#951731)
      bl_current = ::Bootloader::BootloaderFactory.current
      if Mode.update && !(bl_current.read? || bl_current.proposed?)
        Builtins.y2milestone("clean upgrade, do nothing")
        return :auto
      end

      # if BL config is created from scratch, prepare config files
      # in order not to touch old files (bnc#899743)
      if Mode.installation || !bl_current.read?
        Bootloader.blSave(false, false, false)
        @files = BootCommon.GetFilesContents

        Builtins.y2milestone("contents FILES: %1", @files)

        # F#300779 - Install diskless client (NFS-root)
        # kokso: bootloader will not be installed
        @device = BootStorage.disk_with_boot_partition

        if @device == "/dev/nfs"
          Builtins.y2milestone(
            "inst_bootloader -> Boot partition is nfs type, bootloader will not be installed."
          )
          BootCommon.InitializeLibrary(true, "none")
          BootCommon.setLoaderType("none")
        else
          Builtins.foreach(@files) do |file, content|
            last = Builtins.findlastof(file, "/")
            path_file = Builtins.substring(file, 0, last)
            WFM.Execute(
              path(".local.mkdir"),
              Ops.add(Installation.destdir, path_file)
            )
            Builtins.y2milestone("writing file: %1", file)
            WFM.Write(
              path(".local.string"),
              Ops.add(Installation.destdir, file),
              content
            )
          end
        end
      end

      # FATE #302245 save kernel args etc to /etc/sysconfig/bootloader
      sysconfig = ::Bootloader::Sysconfig.new(
        bootloader:  Bootloader.getLoaderType,
        secure_boot: BootCommon.getSystemSecureBootStatus(false)

      )
      sysconfig.pre_write

      Builtins.y2milestone("finish inst_bootloader")

      :auto
    end
  end
end

Yast::InstBootloaderClient.new.main
