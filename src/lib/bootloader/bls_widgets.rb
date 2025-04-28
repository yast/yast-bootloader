# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/systeminfo"
require "bootloader/pmbr"

Yast.import "UI"
Yast.import "Arch"

module Bootloader
  module BlsWidget

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
        CheckBoxFrame(
          Id(:cont_boot),
          _("Automatically boot the default entry after a timeout"),
          false,
          HBox(
            IntField(Id(:seconds), _("&Timeout in Seconds"), @minimum, @maximum,
                     default_value),
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
        current_bl = ::Bootloader::BootloaderFactory.current
        if current_bl.respond_to?(:menu_timeout)
          menu_timeout = current_bl.menu_timeout
          Yast::UI.ChangeWidget(Id(:cont_boot), :Value, menu_timeout >= 0)          
          Yast::UI.ChangeWidget(Id(:seconds), :Value,
                                menu_timeout < 0 ? default_value : menu_timeout)
        else
          log.error("Bootloader #{current_bl} does not support menu_timeout")
          disable
        end
      end

      def store
        current_bl = ::Bootloader::BootloaderFactory.current
        if current_bl.respond_to?(:menu_timeout)
          cont_boot = Yast::UI.QueryWidget(Id(:cont_boot), :Value)
          current_bl.menu_timeout = cont_boot ? Yast::UI.QueryWidget(Id(:seconds), :Value) : -1
        else
          log.error("Bootloader #{current_bl} does not support menu_timeout")
        end
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
  end
end
