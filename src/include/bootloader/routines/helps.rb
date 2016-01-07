# encoding: utf-8

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
module Yast
  module BootloaderRoutinesHelpsInclude
    def initialize_bootloader_routines_helps(_include_target)
      textdomain "bootloader"

      Yast.import "StorageDevices"
      Yast.import "Arch"
    end

    # popup widgets helps

    # Get help
    # @return [String] help text
    def LocationsHelp
      # help text for the custom boot manager installation, 1 of 7
      # %1 = name of boot loader (e.g. "LILO")
      # this should be per architecture
      helptext = Builtins.sformat(
        _(
          "<p><big><b>Boot Loader Location</b></big><br>\nThe boot manager (%1) can be installed in the following ways:</p>"
        ),
        BootCommon.getLoaderType(false)
      )

      # custom bootloader help text, 2 of 7
      helptext = Ops.add(
        helptext,
        _(
          "<p>- In the <b>Master Boot Record</b> (MBR).\n" \
            "This is not recommended if there is another operating system installed\n" \
            "on the computer.</p>"
        )
      )

      # custom bootloader help text, 3 of 7
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" \
            "- In the <b>Boot Sector</b> of the <tt>/boot</tt> or <tt>/</tt> (root) \n" \
            "partition.  This is the recommended option whenever there is a suitable\n" \
            "partition. Either set <b>Activate Boot Loader Partition</b> and\n" \
            "<b>Replace MBR with Generic Code</b> in <b>Boot Loader Installation Details</b>\n" \
            "to update the master boot record\n" \
            "if it is needed or configure your other boot manager\n" \
            "to start &product;.</p>"
        )
      )

      # custom bootloader help text, 5 of 7
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" \
            "- In some <b>Other</b> partition. Consider your system's restrictions\n" \
            "when selecting this option.</p>"
        )
      )
      if Arch.i386
        # optional part, only inserted on x86 architectures. 6 of 7
        helptext = Ops.add(
          helptext,
          _(
            "<p>For example, most PCs have a BIOS\n" \
              "limit that restricts booting to\n" \
              "hard disk cylinders smaller than 1024. Depending on the boot manager used,\n" \
              "you may or may not be able to boot from a logical partition.</p>"
          )
        )
      end

      # custom bootloader help text, 7 of 7
      helptext = Ops.add(
        helptext,
        _(
          "<p>\n" \
            "Enter the device name of the partition (for example, <tt>/dev/hda3</tt> or\n" \
            "<tt>/dev/sdb</tt>) in the input field.</p>"
        )
      )
      helptext
    end

    # Get help text
    # @return [String] help text
    def LoaderOptionsHelp
      # help text 1/1
      _(
        "<p><b>Boot Loader Options</b><br>\n" \
          "To adjust options of the boot loader, such as the time-out, click\n" \
          "<b>Boot Loader Options</b>.</p>"
      )
    end
  end
end
