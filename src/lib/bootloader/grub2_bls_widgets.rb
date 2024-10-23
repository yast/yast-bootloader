# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/systeminfo"

Yast.import "UI"
Yast.import "Arch"

module Bootloader
  module Grub2BlsBootWidget


    class BootloaderTab < CWM::Tab
      def label
        textdomain "bootloader"

        _("Boot&loader Options")
      end

      def contents
        VBox(
          VSpacing(2),
          HBox(
            CWM::Empty.new("options")
          ),
          VStretch()
        )
      end
    end
  end
end
