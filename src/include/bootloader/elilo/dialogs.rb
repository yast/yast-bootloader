# encoding: utf-8

# File:
#      include/bootloader/elilo/elilo_dialogs.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Dialogs for elilo configuration functions
#
# Authors:
#      Jozef Uhliarik <juhliarik@suse.cz>
#
module Yast
  module BootloaderEliloDialogsInclude
    def initialize_bootloader_elilo_dialogs(include_target)
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "CWMTab"
      Yast.import "BootCommon"
      Yast.import "Stage"
      Yast.import "Arch"

      Yast.include include_target, "bootloader/routines/common_options.rb"
      Yast.include include_target, "bootloader/elilo/options.rb"

      @return_tab = "globals"
    end

    # Get the globals dialog tabs description
    # @return a map the description of the tabs
    def EliloTabsDescr
      {
        "globals"          => {
          # tab header
          "header"       => _("&ELILO Global Options"),
          "contents"     => VBox(
            Frame(
              _("Booting Mode"),
              HBox(
                HSpacing(1),
                VBox(Left("noedd30"), Left("prompt"), Left("timeout"))
              )
            ),
            Frame(
              _("Global Section Options"),
              HBox(HSpacing(1), VBox(Left("append"), "image", "initrd"))
            ),
            Frame(
              _("Root Filesystem"),
              HBox(HSpacing(1), VBox(Left("root"), Left("read-only")))
            ),
            VStretch()
          ),
          "widget_names" => [
            "append",
            "image",
            "initrd",
            "noedd30",
            "prompt",
            "root",
            "read-only",
            "timeout"
          ]
        },
        "detailed_globals" => {
          # tab header
          "header"       => _("&Detailed Global Options"),
          "contents"     => VBox(
            Frame(
              _("Other Options"),
              HBox(
                HSpacing(1),
                VBox(
                  Left("message"),
                  Left("chooser"),
                  "fX",
                  Arch.ia64 ? "fpswa" : Empty(),
                  Left("delay"),
                  Left("verbose")
                )
              )
            ),
            VStretch()
          ),
          "widget_names" => Arch.ia64 ?
            ["chooser", "delay", "fX", "fpswa", "verbose", "message"] :
            ["chooser", "delay", "fX", "verbose", "message"]
        }
      }
    end

    # Run dialog for loader installation details for elilo
    # @return [Symbol] for wizard sequencer
    def EliloLoaderDetailsDialog
      Builtins.y2milestone("Running elilo loader details dialog")
      contents = VBox("tab")

      widget_names = ["tab"]
      widget_descr = {}

      widget_descr = Convert.convert(
        Builtins.union(CommonOptions(), EliloOptions()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )

      Ops.set(
        widget_descr,
        "tab",
        CWMTab.CreateWidget(
          {
            "tab_order"    => ["globals", "detailed_globals"],
            "tabs"         => EliloTabsDescr(),
            "widget_descr" => widget_descr,
            "initial_tab"  => @return_tab
          }
        )
      )
      Ops.set(widget_descr, ["tab", "no_help"], "")

      # dialog caption
      caption = _("Boot Loader Global Options")
      ret = CWM.ShowAndRun(
        #"fallback_functions" : global_handlers,
        {
          "widget_descr" => widget_descr,
          "widget_names" => widget_names,
          "contents"     => contents,
          "caption"      => caption,
          "back_button"  => Label.BackButton,
          "abort_button" => Label.CancelButton,
          "next_button"  => Label.OKButton
        }
      )
      if ret != :back && ret != :abort && ret != :cancel
        @return_tab = CWMTab.LastTab
      end
      ret
    end
  end
end
