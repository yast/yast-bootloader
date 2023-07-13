# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/systeminfo"

Yast.import "UI"
Yast.import "Arch"

module Bootloader
  module SystemdBootWidget
    # Adds to generic widget systemd-boot specific helpers
    module SystemdBootHelper
      def systemdboot
        BootloaderFactory.current
      end
    end

    # Represents bootloader timeout value
    class TimeoutWidget < CWM::IntField
      include SystemdBootHelper

      def initialize
        textdomain "bootloader"

        super()

        @minimum = -1
        @maximum = 600
      end

      attr_reader :minimum, :maximum

      def label
        _("&Timeout in Seconds")
      end

      def help
        _("<p><b>Timeout in Seconds</b>\n" \
          "specifies the time the boot loader will wait until the default kernel is loaded.</p>\n")
      end

      def init
        self.value = systemdboot.menue_timeout.to_i
      end

      def store
        systemdboot.menue_timeout = value.to_s
      end
    end

    # represents Tab with kernel related configuration
    class KernelTab < CWM::Tab
      def label
        textdomain "bootloader"

        _("&Kernel Parameters")
      end

      def contents
        VBox(
          VSpacing(1),
          HBox(
            HSpacing(1),
            HStretch()
          ),
          VStretch()
        )
      end
    end

    # Represent tab with options related to stage1 location and bootloader type
    class BootCodeTab < CWM::Tab
      include SystemdBootHelper

      def label
        textdomain "bootloader"

        _("Boot Co&de Options")
      end

      def contents
        VBox(
          VSpacing(1),
          HBox(
            HSpacing(1),
            Left(LoaderTypeWidget.new)
          ),
          VSpacing(1),
          *widgets,
          VStretch()
        )
      end

    private

      def widgets
        w = []

        w.map do |widget|
          MarginBox(horizontal_margin, 0, Left(widget))
        end
      end

      def horizontal_margin
        @horizontal_margin ||= Yast::UI.TextMode ? 1 : 1.5
      end
    end

    # Represents bootloader specific options like its timeout,
    # default section or password protection
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
