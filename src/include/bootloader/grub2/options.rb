# encoding: utf-8

# File:
#      modules/BootGRUB2.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB2 configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id: BootGRUB.ycp 63508 2011-03-04 12:53:27Z jreidinger $
#

require "bootloader/grub2pwd"

module Yast
  module BootloaderGrub2OptionsInclude
    def initialize_bootloader_grub2_options(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "Initrd"

      Yast.include include_target, "bootloader/routines/common_options.rb"
      Yast.include include_target, "bootloader/grub/helps.rb"
      Yast.include include_target, "bootloader/grub2/helps.rb"

      @vga_modes = []
    end
  end
end
