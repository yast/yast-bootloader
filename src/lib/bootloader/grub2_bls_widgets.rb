# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/systeminfo"

Yast.import "UI"
Yast.import "Arch"

module Bootloader
  module Grub2BlsBootWidget

    # Represents bootloader timeout value
    class TimeoutWidget < CWM::CustomWidget

      def initialize
        textdomain "bootloader"

        super()

        @minimum = 0
        @maximum = 600
        @default = 10
      end

      attr_reader :minimum, :maximum, :default

      def contents
        VBox(
          CWM::Empty.new("BootloaderTab")          
        )
#        CheckBoxFrame(
#          Id(:cont_boot),
#          _("Automatically boot the default entry after a timeout"),
#          false,
#          HBox(
#            IntField(Id(:seconds), _("&Timeout in Seconds"), @minimum, @maximum,
#                     1),
#            HStretch()
#          )
#        )
      end
    end

    class BootloaderTab < CWM::Tab

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
