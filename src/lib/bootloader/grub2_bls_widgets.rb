# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/systeminfo"

Yast.import "UI"
Yast.import "Arch"

module Bootloader
  module Grub2BlsBootWidget


    class BootloaderTab < CWM::Tab

      def initialize
        textdomain "bootloader"

        super()

        @minimum = 600
        @maximum = 600
        @default = 600
      end

      def label
        textdomain "bootloader"

        _("Boot&loader Options")
      end

      def contents
        VBox(
          VSpacing(2),
          HBox(
            HSpacing(1),            
            TimeoutWidget.new,
            HSpacing(1)            
          ),
          VStretch()
        )
      end
    end
  end
end
