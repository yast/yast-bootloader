# encoding: utf-8

# File:
#      bootloader_auto.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Bootloader autoinstallation preparation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#

require "installation/auto_client"

module Bootloader
  class BootloaderAutoClient < ::Installation::AutoClient
    include Yast::I18n
    include Yast::Logger

    def initialize
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "Bootloader"
      Yast.import "BootCommon"
      Yast.import "Initrd"
      Yast.import "Progress"
      Yast.import "Mode"

      Yast.include self, "bootloader/routines/autoinstall.rb"
      Yast.include self, "bootloader/routines/wizards.rb"
    end

    def run
      progress_orig = Yast::Progress.set(false)
      super
      Yast::Progress.set(@progress_orig)
    end

    def import(data)
      data = AI2Export(data)
      if data
        ret = Yast::Bootloader.Import(data)
        # moved here from inst_autosetup*
        if Yast::Stage.initial
          Yast::BootCommon.DetectDisks
          Yast::Bootloader.Propose
        end
      else
        ret = false
      end

      ret
    end

    def summary
      formatted_summary = Yast::Bootloader.Summary.map { |l| "<LI>#{l}</LI>" }

      "<UL>" + formatted_summary.join("\n") + "</UL>"
    end

    def modified?
      BootCommon.changed
    end

    def modified
      BootCommon.changed = true
    end

    def reset
      Bootloader.Reset

      {}
    end

    def change
      BootloaderAutoSequence()
    end

    def export
      Export2AI(Yast::Bootloader.Export)
    end

    def write
      Yast::Bootloader.Write
    end

    def read
      Yast::Initrd.Read
      Yast::Bootloader.Read
    end
  end
end
