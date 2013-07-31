# encoding: utf-8

# File:
#      modules/BootPOWERLILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for POWERLILO configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
module Yast
  module BootloaderPpcDialogsInclude
    def initialize_bootloader_ppc_dialogs(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "BootCommon"
      Yast.import "Stage"
      Yast.import "Arch"

      Yast.include include_target, "bootloader/routines/common_options.rb"
      Yast.include include_target, "bootloader/ppc/options.rb"


      @arch_widget_names = ["append", "initrd", "root", "timeout", "activate"]

      @arch_term = Empty()


      # Cache for genericWidgets function
      @_ppc_widgets = nil
    end

    def PPCArchDep
      board_type = getBoardType
      board_type = "prep"
      case board_type
        when "prep"
          @arch_term = Frame(
            _("PReP Specific Settings"),
            HBox(HSpacing(1), VBox("bootfolder"))
          )
          @arch_widget_names = [
            "append",
            "initrd",
            "root",
            "timeout",
            "activate",
            "bootfolder"
          ]
        when "pmac"
          @arch_term = Frame(
            _("Mac Specific Settings"),
            HBox(
              HSpacing(1),
              VBox(Left("no_os_chooser"), Left("macos_timeout"), "bootfolder")
            )
          )
          @arch_widget_names = [
            "append",
            "initrd",
            "root",
            "timeout",
            "activate",
            "no_os_chooser",
            "bootfolder",
            "macos_timeout"
          ]
        when "iseries"

        else
          @arch_term = Frame(
            _("CHRP Specific Settings"),
            HBox(
              HSpacing(1),
              VBox(Left("force_fat"), Left("force"), Left("clone"))
            )
          )
          @arch_widget_names = [
            "append",
            "initrd",
            "root",
            "timeout",
            "activate",
            "force",
            "force_fat",
            "clone"
          ]
      end

      nil
    end

    # Run dialog to adjust installation on i386 and AMD64
    # @return [Symbol] for wizard sequencer
    def PPCDetailsDialog
      Builtins.y2milestone("Running ppc loader details dialog")
      PPCArchDep()

      contents = HBox(
        HSpacing(1),
        VBox(
          Frame(
            _("Global Section Options"),
            HBox(
              HSpacing(1),
              VBox(
                Left("append"),
                "initrd",
                Left("root"),
                "timeout",
                Left("activate")
              )
            )
          ),
          VSpacing(1),
          # add board specific settings
          @arch_term
        )
      )

      widget_names = deep_copy(@arch_widget_names)

      CWM.ShowAndRun(
        {
          "widget_descr" => PPCOptions(),
          "widget_names" => widget_names,
          "contents"     => contents,
          "caption"      => _("Boot Loader Options"),
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.OKButton
        }
      )
    end

    def ppcBootLoaderLocationWidget
      board_type = getBoardType
      board_type = "prep"
      case board_type
        when "prep"
          return BootPReP()
        when "pmac"
          return BootPMAC()
        when "iseries"
          return BootISeries()
        else
          return BootCHRP()
      end
    end

    # Get generic widgets
    # @return a map describing all generic widgets
    def ppcWidgets
      if @_ppc_widgets == nil
        @_ppc_widgets = { "loader_location" => ppcBootLoaderLocationWidget }
      end
      deep_copy(@_ppc_widgets)
    end
  end
end
