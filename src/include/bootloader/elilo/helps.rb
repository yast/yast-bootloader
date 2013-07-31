# encoding: utf-8

# File:
#      include/bootloader/elilo/helps.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Help and label strings for bootloader installation and configuration
#
# Authors:
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
module Yast
  module BootloaderEliloHelpsInclude
    def initialize_bootloader_elilo_helps(include_target)
      textdomain "bootloader"

      @elilo_help_messages = {
        "boot-loader-location" => _(
          "<p><big><b>Boot Loader Location</b></big><br>"
        ),
        "boot"                 => _("<p><b>Boot Image Location</b></p>"),
        "verbose"              => _(
          "<p><b>Set level of verbosity [0-5]</b><br> Increase verbosity of ELILO\nin case of boot problems.</p>"
        ),
        "append"               => _(
          "<p><b>Append string for.global options to pass to kernel command line</b><br>\n" +
            "Lets you define additional global parameters to pass to the kernel. These are\n" +
            "used if no 'append' appears in a given section.</p>\n"
        ),
        "initrd"               => _(
          "<p><b>Name of the default initrd file</b>, if not empty, defines the initial\n" +
            "ramdisk to use. Either enter the path and file name directly or choose by using\n" +
            "<b>Browse</b></p>\n"
        ),
        "image"                => _(
          "<p><b>Name of default image file</b>, if not empty, defines the image\n" +
            "file to use. Either enter the path and file name directly or choose by using\n" +
            "<b>Browse</b></p>"
        ),
        "chooser"              => _(
          "<p><b>Specify user interface for ELILO ('simple' or 'textmenu')</b><br>\nBeware: 'textmenu' has occasionally caused problems on some machines.</p>"
        ),
        "noedd30"              => _(
          "<p><b>Prevent EDD30 mode</b><br>\n" +
            "By default, if EDD30 is off, ELILO will try and set the variable to TRUE.\n" +
            "However, some controllers do not support EDD30 and forcing the variable\n" +
            "may cause problems. Therefore, as of elilo-3.2, there is an option to \n" +
            "avoid forcing the variable.</p>\n"
        ),
        "relocatable"          => _(
          "<p><b>Allow attempt to relocate</b><br>\n" +
            "In case of memory allocation error at initial load point of\n" +
            "kernel, allow attempt to relocate (assume this kernel is relocatable).\n" +
            "</p>"
        ),
        "prompt"               => _(
          "<p><b>Force Interactive Mode</b>\nForce interactive mode during booting</p>"
        ),
        "root"                 => _(
          "<p><b>Set Default Root Filesystem</b>\nSet global root filesystem for Linux/ia64</p>"
        ),
        "chooser"              => _(
          "<p><b>Set the User Interface for ELILO</b>\nSpecify kernel chooser to use: \"simple\" or \"textmenu\"</p>"
        ),
        "fX"                   => _(
          "<p><b>Display the Content of a File by Function Keys</b>\n" +
            "Some choosers may take advantage of this option to\n" +
            "display the content of a file when a certain function\n" +
            "key X is pressed. X can vary from 1-12 to cover\n" +
            "function keys F1 to F12</p>"
        ),
        "fpswa"                => _(
          "<p><b>Specify the Filename for a Specific FPSWA to Load</b>\n" +
            "Specify the filename for a specific FPSWA to load.\n" +
            "If this option is used then no other file will be tried.</p>"
        ),
        "message"              => _(
          "<p><b>Message Printed on Main Screen (If Supported)</b>\n" +
            "A message that is printed on the main screen if supported by\n" +
            "the chooser.</p>"
        ),
        "delay"                => _(
          "<p><b>Delay to Wait before Auto Booting in Seconds</b>\n" +
            "The number of 10th of seconds to wait before\n" +
            "auto booting when not in interactive mode.\n" +
            "Default is 0</p>"
        )
      }


      @elilo_descriptions = {
        "boot"        => _("Boot Image Location"),
        "delay"       => _(
          "Delay to wait before auto booting in seconds (used if not in interactive mode)"
        ),
        "prompt"      => _("Force interactive mode"),
        "verbose"     => _("Set level of verbosity [0-5]"),
        "root"        => _("Set default root filesystem"),
        "readonly"    => _("Force rootfs to be mounted read-only"),
        "append"      => _(
          "Global append string of options to kernel command line"
        ),
        "initrd"      => _("Name of default initrd file"),
        "image"       => _("Name of default image file"),
        "chooser"     => _(
          "Specify user interface for ELILO ('simple' or 'textmenu')"
        ),
        "message"     => _("Message printed on main screen (if supported)"),
        "fX"          => _("Display the content of a file by function keys"),
        "noedd30"     => _("Prevent EDD30 mode"),
        "fpswa"       => _("Specify the filename for a specific FPSWA to load"),
        "relocatable" => _("Allow attempt to relocate"),
        "boot_custom" => _("Custom Boot Partition")
      }
    end
  end
end
