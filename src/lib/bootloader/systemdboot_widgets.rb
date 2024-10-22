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
    class TimeoutWidget < CWM::CustomWidget
      include SystemdBootHelper

      def initialize
        textdomain "bootloader"

        super()

        @minimum = 0
        @maximum = 600
        @default = 10
      end

      attr_reader :minimum, :maximum, :default

      def contents
        CheckBoxFrame(
          Id(:cont_boot),
          _("Automatically boot the default entry after a timeout"),
          false,
          HBox(
            IntField(Id(:seconds), _("&Timeout in Seconds"), @minimum, @maximum,
              systemdboot.menu_timeout.to_i),
            HStretch()
          )
        )
      end

      def help
        _("<p>Continue boot process after defined seconds.</p>" \
          "<p><b>Timeout in Seconds</b>\n" \
          "specifies the time the boot loader will wait until the default kernel is loaded.</p>\n")
      end

      def init
        Yast::UI.ChangeWidget(Id(:cont_boot), :Value, systemdboot.menu_timeout >= 0)
        systemdboot.menu_timeout = default_value if systemdboot.menu_timeout < 0
        Yast::UI.ChangeWidget(Id(:seconds), :Value, systemdboot.menu_timeout)
      end

      def store
        cont_boot = Yast::UI.QueryWidget(Id(:cont_boot), :Value)
        systemdboot.menu_timeout = cont_boot ? Yast::UI.QueryWidget(Id(:seconds), :Value) : -1
      end

    private

      def default_value
        # set default
        ret = Yast::ProductFeatures.GetIntegerFeature("globals",
          "boot_timeout").to_i
        ret = @default if ret <= 0
        ret
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
