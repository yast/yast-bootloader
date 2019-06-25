# frozen_string_literal: true

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
    include Yast::Logger
    def main
      textdomain "bootloader"

      Yast.import "Bootloader"
      # Yast.import "BootCommon"
      Yast.import "Installation"
      Yast.import "GetInstArgs"
      Yast.import "Mode"

      log.info "starting inst_bootloader"

      if GetInstArgs.going_back # going backwards?
        return :auto # don't execute this once more
      end

      # for upgrade that is from grub2 to grub2 and user do not want
      # any changes, just quit (bnc#951731)
      bl_current = ::Bootloader::BootloaderFactory.current
      if Mode.update && !(bl_current.read? || bl_current.proposed?)
        log.info "clean upgrade, do nothing"
        return :auto
      end

      bl_current.write_sysconfig(prewrite: true)

      log.info "finish inst_bootloader"

      :auto
    end
  end
end

Yast::InstBootloaderClient.new.main
