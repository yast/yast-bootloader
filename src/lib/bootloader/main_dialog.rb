require "yast"

require "bootloader/config_dialog"
require "bootloader/read_dialog"
require "bootloader/write_dialog"

Yast.import "BootCommon"
Yast.import "Label"
Yast.import "Report"
Yast.import "Sequencer"
Yast.import "Stage"
Yast.import "UI"
Yast.import "Wizard"


module Bootloader
  class MainDialog
    include Yast::UIShortcuts
    include Yast::I18n

    # Whole configuration of printer but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def run_auto
      Yast::Wizard.CreateDialog
      Yast::Wizard.SetContentsButtons(
        "",
        VBox(),
        "",
        Yast::Label.BackButton,
        Yast::Label.NextButton
      )
      if Yast::Stage.initial
        Yast::Wizard.SetTitleIcon("bootloader") # no .desktop file in inst-sys
      else
        Yast::Wizard.SetDesktopTitleAndIcon("bootloader")
      end

      ret = run_content
      Yast::UI.CloseDialog
      ret
    end

    # Whole configuration of dns-server
    # @return sequence result
    def run
      my_aliases = {
        "read"  => [lambda { ReadDialog.new.run }, true],
        "main"  => method(:run_content),
        "write" => [lambda { WriteDialog.new.run }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Yast::Wizard.CreateDialog
      Yast::Wizard.SetDesktopTitleAndIcon("bootloader")
      Yast::Wizard.SetContentsButtons(
        "",
        VBox(),
        "",
        Yast::Label.BackButton,
        Yast::Label.NextButton
      )
      ret = Yast::Sequencer.Run(my_aliases, sequence)

      Yast::Wizard.CloseDialog
      ret
    end

  private

    # Run wizard sequencer
    # @return `next, `back or `abort
    def run_content
      if !Yast::BootCommon.BootloaderInstallable
        textdomain "bootloader"

        # error report
        Yast::Report.Error(
          _(
            "Because of the partitioning, the boot loader cannot be installed properly."
          )
        )
      end

      # run generic sequence
      aliases = {
        "main"                 => lambda { ConfigDialog.new.run },
        "installation_details" => lambda { DetailsDialog("installation") },
        "loader_details"       => lambda { DetailsDialog("loader") }
      }

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
        "loader_details"       => { :next => "main", :abort => :abort }
      }

      Yast::Sequencer.Run(aliases, sequence)
    end
  end
end
