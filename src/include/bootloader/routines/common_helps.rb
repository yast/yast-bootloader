# encoding: utf-8

# File:
#      include/bootloader/grup/helps.ycp
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
  module BootloaderRoutinesCommonHelpsInclude
    def initialize_bootloader_routines_common_helps(_include_target)
      textdomain "bootloader"

      @common_help_messages = {
        "timeout" => _(
          "<p><b>Timeout in Seconds</b><br>\nSpecifies the time the bootloader will wait until the default kernel is loaded.</p>\n"
        )
      }

      @common_descriptions = { "timeout" => _("&Timeout in Seconds") }
    end
  end
end
