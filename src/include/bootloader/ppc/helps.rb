# encoding: utf-8

# File:
#      include/bootloader/ppc/helps.ycp
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
  module BootloaderPpcHelpsInclude
    def initialize_bootloader_ppc_helps(include_target)
      textdomain "bootloader"

      @ppc_help_messages = {
        "boot-loader-location" => _(
          "<p><big><b>Boot Loader Location</b></big><br>"
        ),
        "boot"                 => _(
          "<p><b>Boot Location</b>\n" +
            "This is the partition number of your boot partition. On a\n" +
            "PowerMac it must be in HFS format because we use the hfsutils to\n" +
            "copy the files to that partition. On CHRP you need a 41 PReP\n" +
            "boot partition, /boot/second from the quik package is stored there </p>"
        ),
        "bootfolder"           => _(
          "<p><b>Boot Folder Path</b>\n" +
            "Only for Pmac. Folder that contains your boot stuff, this\n" +
            "folder will be blessed to mark it bootable.</p>"
        ),
        "append"               => _(
          "<p><b>Append String for Global Options to Pass to Kernel Command Line</b><br>\n" +
            "Lets you define additional global parameters to pass to the kernel. These are\n" +
            "used if no 'append' appears in a given section.</p>\n"
        ),
        "initrd"               => _(
          "<p><b>Name of the Default Initrd File</b>, if not empty, defines the initial\n" +
            "ramdisk to use. Either enter the path and file name directly or choose by using\n" +
            "<b>Browse</b></p>\n"
        ),
        "image"                => _(
          "<p><b>Name of Default Image File</b>, if not empty, defines the image\n" +
            "file to use. Either enter the path and file name directly or choose by using\n" +
            "<b>Browse</b></p>"
        ),
        "root"                 => _(
          "<p><b>Set Default Root Filesystem</b>\nSet global root filesystem for Linux</p>"
        ),
        "clone"                => _(
          "<p><b>Partition for Boot Loader Duplication</b>\n" +
            "specifies other Linux device nodes where the bootinfo should be stored.\n" +
            "If this option is given, the boot partition will be converted to FAT. \n" +
            "The intend of this option is to write the boot files to all members of a RAID1 or RAID5 system.</p>"
        ),
        "activate"             => _(
          "<p><b>Change Boot Device in NV-RAM</b>\n" +
            "this option will tell lilo to update the OpenFirmware \"boot-device\" \n" +
            "variable with the full OpenFirmware path pointing to the device specified in\n" +
            "\"boot=\". If this option is missing, the system may not boot.</p>"
        ),
        "no_os_chooser"        => _(
          "<p><b>Do not Use OS-chooser</b>\n" +
            " will tell lilo to use yaboot as boot file instead of a Forth script named \"os-chooser\". \n" +
            "The OpenFirmware driver in the nVidia graphics card as shipped with Apple G5 systems \n" +
            "will crash if there is no monitor attached.</p>"
        ),
        "macos_timeout"        => _(
          "<p><b>Timeout in Seconds for MacOS/Linux</b>\n" +
            "It contains the timeout between MacOS/Linux in seconds until Linux boots automatically \n" +
            "if no key is pressed to boot MacOS</p>"
        ),
        "force_fat"            => _(
          "<p><b>Always Boot from FAT Partition</b>\n" +
            "Normally the lilo script would automatically select the boot partition format\n" +
            "to either be a PReP boot partition or a FAT formatted file system for more\n" +
            "complex setups. This option forces the lilo script to use\n" +
            "the FAT formatted file system</p>"
        ),
        "force"                => _(
          "<p><b>Install Boot Loader Even on Errors</b>\n" +
            "Install the bootloader even if it is unsure whether your firmware is\n" +
            "buggy so that next boot will fail. This results in an unsupported setup.</p>"
        )
      }


      @ppc_descriptions = {
        "boot"                => _("PPC Boot Loader Location"),
        "activate"            => _("Change Boot Device in NV-RAM"),
        "timeout"             => _("Time-Out in Tenths of Seconds"),
        "default"             => _("Default Boot Section"),
        "root"                => _("Default Root Device"),
        "append"              => _("Append Options for Kernel Command Line"),
        "initrd"              => _("Default initrd Path"),
        "clone"               => _("Partition for Boot Loader Duplication"),
        "force_fat"           => _("Always Boot from FAT Partition"),
        "no_os_chooser"       => _("Do not use OS-chooser"),
        "force"               => _("Install Boot Loader Even on Errors"),
        "boot_chrp_custom"    => _("PReP or FAT Partition"),
        "bootfolder"          => _("Boot Folder Path"),
        "boot_prep_custom"    => _("PReP Partition"),
        "boot_slot"           => _("Write to Boot Slot"),
        "boot_file"           => _("Create Boot Image in File"),
        "boot_iseries_custom" => _("PReP Partition"),
        "boot_pmac_custom"    => _("HFS Boot Partition")
      }
    end
  end
end
