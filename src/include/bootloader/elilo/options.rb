# encoding: utf-8

# File:
#      modules/BootELILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for ELILO configuration
#      and installation
#
# Authors:
#      Joachim Plack <jplack@suse.de>
#      Jiri Srain <jsrain@suse.cz>
#      Andreas Schwab <schwab@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
module Yast
  module BootloaderEliloOptionsInclude
    def initialize_bootloader_elilo_options(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "BootCommon"

      Yast.include include_target, "bootloader/elilo/helps.rb"
    end

    # Common widgets of global settings for ELILO
    # @return [Hash{String => map<String,Object>}] CWS widgets
    def EliloOptions
      elilo_specific = {
        "append"    => CommonInputFieldWidget(
          _("Global Append &String of Options to Kernel Command Line"),
          Ops.get(@elilo_help_messages, "append", "")
        ),
        "image"     => CommonInputFieldBrowseWidget(
          _("&Name of Default Image File"),
          Ops.get(@elilo_help_messages, "image", ""),
          "image"
        ),
        "initrd"    => CommonInputFieldBrowseWidget(
          _("Nam&e of Default Initrd File"),
          Ops.get(@elilo_help_messages, "initrd", ""),
          "initrd"
        ),
        "root"      => CommonInputFieldWidget(
          _("Set Default &Root Filesystem"),
          Ops.get(@elilo_help_messages, "root", "")
        ),
        "noedd30"   => CommonCheckboxWidget(
          _("&Prevent EDD30 Mode"),
          Ops.get(@elilo_help_messages, "noedd30", "")
        ),
        "prompt"    => CommonCheckboxWidget(
          _("&Force Interactive Mode"),
          Ops.get(@elilo_help_messages, "prompt", "")
        ),
        "read-only" => CommonCheckboxWidget(
          _("Force rootfs to Be Mounted Read-Only"),
          Ops.get(@elilo_help_messages, "image_readonly", "")
        ),
        "timeout"   => TimeoutWidget(),
        "chooser"   => CommonInputFieldWidget(
          _("&Set the User Interface for ELILO (\"simple\" or \"textmenu\")"),
          Ops.get(@elilo_help_messages, "chooser", "")
        ),
        "delay"     => CommonIntFieldWidget(
          _(
            "&Delay to Wait before Auto Booting in Seconds (Used if not in Interactive Mode)"
          ),
          Ops.get(@elilo_help_messages, "delay", ""),
          0,
          10000
        ),
        "fX"        => CommonInputFieldBrowseWidget(
          _("Display the Content of a File by Function &Keys"),
          Ops.get(@elilo_help_messages, "fX", ""),
          "fX"
        ),
        "fpswa"     => CommonInputFieldBrowseWidget(
          _("&Specify the Filename for a Specific FPSWA to Load"),
          Ops.get(@elilo_help_messages, "fpswa", ""),
          "fpswa"
        ),
        "verbose"   => CommonIntFieldWidget(
          _("Set Level of &Verbosity [0-5]"),
          Ops.get(@elilo_help_messages, "verbose", ""),
          0,
          5
        ),
        "message"   => CommonInputFieldWidget(
          _("&Message Printed on Main Screen (If Supported)"),
          Ops.get(@elilo_help_messages, "message", "")
        )
      }
      deep_copy(elilo_specific)
    end
  end
end
