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
  module BootloaderGrubHelpsInclude
    def initialize_bootloader_grub_helps(_include_target)
      textdomain "bootloader"

      @grub_help_messages = {
        "boot-menu"         => _("<p><big><b>Boot Menu</b></big><br></p>"),
        "activate"          => _(
          "<p><b>Set active Flag in Partition Table for Boot Partition</b><br>\n" \
            "To activate the partition which contains the boot loader. The generic MBR code will then\n" \
            "boot the active partition. Older BIOSes require one partition to be active even\n" \
            "if the boot loader is installed in the MBR.</p>"
        ),
        "timeout"           => _(
          "<p><b>Timeout in Seconds</b><br>\nSpecifies the time the bootloader will wait until the default kernel is loaded.</p>\n"
        ),
        "default"           => _(
          "<p> By pressing <b>Set as Default</b> you mark the selected section as\n" \
            "the default. When booting, the boot loader will provide a boot menu and\n" \
            "wait for the user to select a kernel or OS to boot. If no\n" \
            "key is pressed before the timeout, the default kernel or OS will\n" \
            "boot. The order of the sections in the boot loader menu can be changed\n" \
            "using the <b>Up</b> and <b>Down</b> buttons.</p>\n"
        ),
        "generic_mbr"       => _(
          "<p><b>Write generic Boot Code to MBR</b> replace the master boot record of your disk with generic code (OS independent code which\nboots the active partition).</p>"
        ),
        "boot_boot"         => _(
          "<p><b>Boot from Boot Partition</b> is one of the recommended options, the other is\n<b>Boot from Root Partition</b>.</p>"
        ),
        "boot_mbr"          => _(
          "<p><b>Boot from Master Boot Record</b> is not recommended if you have another operating system\ninstalled on your computer</p>"
        ),
        "boot_root"         => _(
          "<p><b>Boot from Root Partition</b> is the recommended option whenever there is a suitable\n" \
            "partition. Either select <b>Set active Flag in Partition Table for Boot Partition</b> and <b>Write generic Boot Code to MBR</b>\n" \
            "in <b>Boot Loader Options</b> to update the master boot record if that is needed or configure your other boot manager\n" \
            "to start this section.</p>"
        ),
        "boot_extended"     => _(
          "<p><b>Boot from Extended Partition</b> should be selected if your root partition is on \nlogical partition and the /boot partition is missing</p>"
        ),
        "boot_custom"       => _(
          "<p><b>Custom Boot Partition</b> lets you choose a partition to boot from.</p>"
        ),
        "enable_redundancy" => _(
          "<p>MD array is build from 2 disks. <b>Enable Redundancy for MD Array</b>\nenable to write GRUB to MBR of both disks.</p>"
        ),
        "serial"            => _(
          "<p><b>Use Serial Console</b> lets you define the parameters to use\nfor a serial console. Please see the grub documentation (<code>info grub2</code>) for details.</p>"
        ),
        "terminal"          => _(
          "<p><b>Terminal Definition</b></p><br>\n" \
            "Defines the type of terminal you want to use. For a serial terminal (e.g. a serial console),\n" \
            "you have to specify <code>serial</code>. You can also pass <code>console</code> to the\n" \
            "command, as <code>serial console</code>. In this case, a terminal in which you\n" \
            "press any key will be selected as a GRUB terminal.</p>"
        ),
        "fallback"          => _(
          "<p><b>Fallback Sections if default Fails</b> contains a list of section numbers\nthat will be used for booting in case the default section is unbootable.</p>"
        ),
        "hiddenmenu"        => _(
          "<p>Selecting <b>Hide Menu on Boot</b> will hide the boot menu.</p>"
        ),
        "password"          => _(
          "<p><b>Protect Boot Loader with Password</b><br>\n" \
            "At boot time, modifying or even booting any entry will require the" \
            " password. If <b>Protect Entry Modification Only</b> is checked then " \
            "booting any entry is not restricted but modifying entries requires " \
            "the password (which is the way GRUB 1 behaved).<br>" \
            "YaST will only accept the password if you repeat it in " \
            "<b>Retype Password</b>.</p>"
        ),
        # help text 1/5
        "disk_order"        => _(
          "<p><big><b>Disks Order</b></big><br>\n" \
            "To specify the order of the disks according to the order in BIOS, use\n" \
            "the <b>Up</b> and <b>Down</b> buttons to reorder the disks.\n" \
            "To add a disk, push <b>Add</b>.\n" \
            "To remove a disk, push <b>Remove</b>.</p>"
          )
      }

      @grub_descriptions = {
        "boot"          => _("Boot Loader Locations"),
        "activate"      => _(
          "Set &active Flag in Partition Table for Boot Partition"
        ),
        "timeout"       => _("&Timeout in Seconds"),
        "default"       => _("&Default Boot Section"),
        "generic_mbr"   => _("Write &generic Boot Code to MBR"),
        "boot_custom"   => _("Custom Boot Partition"),
        "boot_mbr"      => _("Boot from Master Boot Record"),
        "boot_root"     => _("Boot from Root Partition"),
        "boot_boot"     => _("Boot from Boot Partition"),
        "boot_extended" => _("Boot from Extended Partition"),
        "serial"        => _("Serial Connection &Parameters"),
        "fallback"      => _("Fallback Sections if Default fails"),
        "hiddenmenu"    => _("&Hide Menu on Boot"),
        "password"      => _("Pa&ssword for the Menu Interface"),
        "debug"         => _("Debugg&ing Flag")
      }
    end
  end
end
