# frozen_string_literal: true

# File:
#      bootloader.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Main file of bootloader configuration
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
require "yast"

require "bootloader/main_dialog"

module Yast
  class BootloaderClient < Client
    def main
      textdomain "bootloader"

      Yast.import "CommandLine"

      # the command line description map
      cmdline = {
        "id"         => "bootloader",
        # command line help text for Bootloader module
        "help"       => _("Boot loader configuration module"),
        "guihandler" => fun_ref(method(:GuiHandler), "boolean ()")
      }

      CommandLine.Run(cmdline)
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # CommandLine handler for running GUI
    # @return [Boolean] true if settings were saved
    def GuiHandler
      ret = ::Bootloader::MainDialog.new.run

      return false if ret == :abort || ret == :back || ret == :nil

      true
    end
  end
end

Yast::BootloaderClient.new.main
