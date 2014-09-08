# encoding: utf-8

# File:
#      include/bootloader/routines/wizards.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Wizard sequences for bootloader installation/configuration
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
module Yast
  module BootloaderRoutinesWizardsInclude
    def initialize_bootloader_routines_wizards(include_target)
      Yast.import "UI"
      textdomain "bootloader"

      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.include include_target, "bootloader/routines/dialogs.rb"
    end

    # Run wizard sequencer
    # @return `next, `back or `abort
    def MainSequence
      if !BootCommon.BootloaderInstallable
        # error report
        Report.Error(
          _(
            "Because of the partitioning, the boot loader cannot be installed properly."
          )
        )
      end

      # run generic sequence
      aliases = {
        "main"                 => lambda { MainDialog() },
        "installation_details" => lambda { DetailsDialog("installation") },
        "loader_details"       => lambda { DetailsDialog("loader") },
      }

      @return_tab = Bootloader.getLoaderType != "none" ? "sections" : "installation"

      sequence = {
        "ws_start"             => "main",
        "main"                 => {
          :next           => :next,
          :abort          => :abort,
          :inst_details   => "installation_details",
          :loader_details => "loader_details",
          :redraw         => "main"
        },
        "installation_details" => { :next => "main", :abort => :abort },
        "loader_details"       => { :next => "main", :abort => :abort },
      }

      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of printer but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def BootloaderAutoSequence
      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        "",
        VBox(),
        "",
        Label.BackButton,
        Label.NextButton
      )
      if Stage.initial
        Wizard.SetTitleIcon("bootloader") # no .desktop file in inst-sys
      else
        Wizard.SetDesktopTitleAndIcon("bootloader")
      end

      ret = MainSequence()
      UI.CloseDialog
      ret
    end

    # Whole configuration of dns-server
    # @return sequence result
    def BootloaderSequence
      my_aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("bootloader")
      Wizard.SetContentsButtons(
        "",
        VBox(),
        "",
        Label.BackButton,
        Label.NextButton
      )
      ret = Sequencer.Run(my_aliases, sequence)

      UI.CloseDialog
      ret
    end
  end
end
