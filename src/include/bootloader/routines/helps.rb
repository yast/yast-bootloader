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

    # wizard sequecer widgets helps

    # Get help
    # @return [String] help text
    def getAdvancedButtonHelp
      ins = ""
      # help text 1/2 (%1 may be following sentence, optionally empty)
      help = Builtins.sformat(
        _(
          "<P>From <B>Other</B>,\n" \
            "you can manually edit the boot loader configuration files, clear the current \n" \
            "configuration and propose a new configuration, start from scratch, or reread\n" \
            "the configuration saved on your disk. %1</P>"
        ),
        ins
      )
      help
    end

    # Get help
    # @return [String] help text
    def getManualEditHelp
      # help text 1/1
      _(
        "<P>To edit boot loader configuration files\nmanually, click <B>Edit Configuration Files</B>.</P>"
      )
    end

    # Get help
    # @return [String] help text
    def SectionsHelp
      # help 1/4
      _(
        "<P> In the table, each section represents one item\nin the boot menu.</P>"
      ) +
        # help 2/4
        _(
          "<P> Press <B>Edit</B> to display the properties of the\nselected section.</P>"
        ) +
        # help 3/4
        _(
          "<P> By pressing <b>Set as Default</b>, mark the selected \n" \
            "section as default. When booting, the boot loader will provide \n" \
            "a boot menu and wait for the user to select the kernel or other \n" \
            "OS to boot. If no key is pressed before the time-out, the default \n" \
            "kernel or OS will be booted. The order of sections in the boot loader\n" \
            "menu can be changed using the <B>Up</B> and <B>Down</B> buttons.</P>"
        ) +
        # help 4/4
        _(
          "<P>Press <B>Add</B> to create a new boot loader section\nor <B>Delete</B> to delete the selected section.</P>"
        )
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
    def InstDetailsHelp
      # help text 1/1
      _(
        "<p><b>Boot Loader Installation Details</b><br>\n" \
          "To adjust advanced boot loader installation options (such as the device\n" \
          "mapping), click <b>Boot Loader Installation Details</b>.</p>"
      )
    end

    # Get help text
    # @return [String] help text
    def LoaderTypeHelp
      # help text 1/1
      _(
        "<p><b>Boot Loader Type</b><br>\n" \
          "To select whether to install a boot loader and which bootloader to install,\n" \
          "use <b>Boot Loader</b>.</p>"
      )
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

    # Get help
    # @return [String] help text
    def getExpertManualHelp
      # help text 1/1
      _(
        "<P><B>Expert Manual Configuration</B><BR>\n" \
          "Here, manually edit the boot loader configuration.</P>\n" \
          "<P>Note: The final configuration file may have different indenting.</P>"
      )
    end

    # Get help text
    # @return [String] help text
    def SectionNameHelp
      # help text 1/1
      _(
        "<p><b>Section Name</b><br>\n" \
          "Use <b>Section Name</b> to specify the boot loader section name. The section\n" \
          "name must be unique.</p>"
      )
    end

    # Get help text
    # @return [String] help text
    def SectionTypeHelp
      # help text 1/5
      _(
        "<p><big><b>Type of the New Section</b></big><br>\nSelect the type of the new section to create.</p>"
      ) +
        # help text 2/5
        _(
          "<p>Select <b>Clone Selected Section</b> to clone the currently selected\n" \
            "section. Then modify the options that should differ from the\n" \
            "selected section.</p>"
        ) +
        # help text 3/5
        _(
          "<p>Select <b>Image Section</b> to add a new Linux kernel or other image\nto load and start.</p>"
        ) +
        # help text 4/5
        _(
          "<p>Select <b>Xen Section</b> to add a new Linux kernel or other image,\nbut to start it in a Xen environment.</p>"
        ) +
        # help text 5/5
        _(
          "<p>Select <b>Other System (Chainloader)</b> to add a section that \n" \
            "loads and starts a boot sector of a partition of the disk. This is used for\n" \
            "booting other operating systems.</p>"
        ) +
        _(
          "<p>Select <b>Menu Section</b> to add a section that \n" \
            "loads configuration file (the list of boot sections) from a partition of the disk. This is used for\n" \
            "booting other operating systems.</p>"
        )
    end
  end
end
