# encoding: utf-8

# File:
#      include/bootloader/grup2/helps.ycp
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
# $Id: helps.ycp 58279 2009-08-04 16:01:51Z juhliarik $
#
module Yast
  module BootloaderGrub2HelpsInclude
    def initialize_bootloader_grub2_helps(_include_target)
      textdomain "bootloader"

      @grub2_help_messages = {
        "vgamode"   => _(
          "<p><b>Vga Mode</b> defines the VGA mode the kernel should set the <i>console</i> to when booting.</p>"
        ),
        "pmbr"      => _(
          "<p><b>Protective MBR flag</b> is expert only settings, that is needed only on exotic hardware. For details see Protective MBR in GPT disks. Do not touch if you are not sure.</p>"
        )
      }

      @grub2_descriptions = {
        "vgamode"   => _("&Vga Mode"),
        "pmbr"      => _("Protective MBR flag")
      }
    end
  end
end
