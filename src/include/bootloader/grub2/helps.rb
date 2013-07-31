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
    def initialize_bootloader_grub2_helps(include_target)
      textdomain "bootloader"

      @grub2_help_messages = {
        "append"          => _(
          "<p><b>Optional Kernel Command Line Parameter</b> lets you define additional parameters to pass to the kernel.</p>"
        ),
        "vgamode"         => _(
          "<p><b>Vga Mode</b> defines the VGA mode the kernel should set the <i>console</i> to when booting.</p>"
        ),
        "append_failsafe" => _(
          "<p><b>Failsafe Kernel Command Line Parameter</b> lets you define failsafe parameters to pass to the kernel.</p>"
        ),
        "os_prober"       => _(
          "<p><b>Probe Foreign OS</b> by means of os-prober for multiboot with other foreign distribution </p>"
        )
      }

      @grub2_descriptions = {
        "append"          => _("O&ptional Kernel Command Line Parameter"),
        "vgamode"         => _("&Vga Mode"),
        "append_failsafe" => _("&Failsafe Kernel Command Line Parameter"),
        "os_prober"       => _("Probe Foreign OS")
      }
    end
  end
end
