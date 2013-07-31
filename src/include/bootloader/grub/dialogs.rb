# encoding: utf-8

# File:
#      include/bootloader/grub/dialogs.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Dialogs for configuraion i386-specific functions
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id: dialogs_i386.ycp 56563 2009-04-02 08:41:25Z jreidinger $
#
module Yast
  module BootloaderGrubDialogsInclude
    def initialize_bootloader_grub_dialogs(include_target)
      Yast.import "UI"
      textdomain "bootloader"


      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "BootCommon"
      Yast.import "Stage"

      Yast.include include_target, "bootloader/grub/options.rb"

      # Cache for genericWidgets function
      @_grub_widgets = nil
    end

    # Run dialog to adjust installation on i386 and AMD64
    # @return [Symbol] for wizard sequencer
    def i386InstallDetailsDialog
      contents = HBox(
        HStretch(),
        VBox(VStretch(), Frame(_("Disk Order"), "disks_order"), VStretch()),
        HStretch()
      )

      CWM.ShowAndRun(
        {
          "widget_descr" => { "disks_order" => DisksOrderWidget() },
          "widget_names" => ["disks_order"],
          "contents"     => contents,
          "caption"      => _("Disk order settings"),
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.OKButton
        }
      )
    end

    # Run dialog for loader installation details on i386
    # @return [Symbol] for wizard sequencer
    def i386LoaderDetailsDialog
      Builtins.y2milestone("Running i386 loader details dialog")

      contents = HBox(
        HSpacing(2),
        VBox(
          VStretch(),
          Frame(
            _("Boot Menu"),
            HBox(
              HSpacing(2),
              VBox(
                Left("activate"),
                Left("generic_mbr"),
                HBox(
                  VBox(Left("debug"), Left("hiddenmenu")),
                  HSpacing(2),
                  VBox(Left("trusted_grub"), Left("acoustic_signals"))
                ),
                Left("gfxmenu"),
                Left(HSquash("timeout"))
              ),
              HStretch()
            )
          ),
          #`VSpacing(1),
          Left("password"),
          #`VSpacing(1),
          Left("console"),
          VStretch()
        ),
        HSpacing(2)
      )

      widget_names = [
        "activate",
        "debug",
        "generic_mbr",
        "acoustic_signals",
        "trusted_grub",
        "hiddenmenu",
        "gfxmenu",
        "timeout",
        "console",
        "password"
      ]
      caption = _("Boot Loader Options")
      CWM.ShowAndRun(
        {
          "widget_descr" => GrubOptions(),
          "widget_names" => widget_names,
          "contents"     => contents,
          "caption"      => caption,
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.OKButton
        }
      )
    end

    # Get generic widgets
    # @return a map describing all generic widgets
    def grubWidgets
      if @_grub_widgets == nil
        @_grub_widgets = {
          "loader_location" => grubBootLoaderLocationWidget,
          "inst_details"    => grubInstalationDetials
        }
      end
      deep_copy(@_grub_widgets)
    end
  end
end
