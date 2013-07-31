# encoding: utf-8

# File:
#      include/bootloader/zipl/helps.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Help and label strings for bootloader installation and configuration
#
# Authors:
#      Joachim Plack <jplack@suse.de>
#
# $Id$
#
module Yast
  module BootloaderZiplHelpsInclude
    def initialize_bootloader_zipl_helps(include_target)
      textdomain "bootloader"

      @zipl_help_messages = {}


      @zipl_descriptions = {
        "boot"    => _("Boot Image Location"),
        "default" => _("Default Boot Section/Menu")
      }
    end
  end
end
