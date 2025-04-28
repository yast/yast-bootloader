# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/bls_widgets"
require "bootloader/systeminfo"
require "bootloader/pmbr"

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

    # Represents switcher for secure boot on EFI
    class SecureBootWidget < CWM::CheckBox
      include SystemdBootHelper

      def initialize
        textdomain "bootloader"

        super
      end

      def label
        _("&Secure Boot Support")
      end

      def help
        _(
          "<p><b>Secure Boot Support</b> if checked enables Secure Boot support.<br>" \
          "This does not turn on secure booting. " \
          "It only sets up the boot loader in a way that supports secure booting. " \
          "You still have to enable Secure Boot in the UEFI Firmware.</p> "
        )
      end

      def init
        self.value = systemdboot.secure_boot
      end

      def store
        systemdboot.secure_boot = value
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
          MarginBox(1, 0.5, KernelAppendWidget.new),
          MarginBox(1, 0.5, Left(CpuMitigationsWidget.new)),
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
          VSpacing(1),
          pmbr_widget,
          VStretch()
        )
      end

    private

      def widgets
        w = []
        if Yast::Stage.initial && # while new installation only (currently)
            secure_boot_widget?
          w << SecureBootWidget.new
        end

        w.map do |widget|
          MarginBox(horizontal_margin, 0, Left(widget))
        end
      end

      def pmbr_widget
        return Empty() unless pmbr_widget?

        MarginBox(1, 0, Left(PMBRWidget.new))
      end

      def horizontal_margin
        @horizontal_margin ||= Yast::UI.TextMode ? 1 : 1.5
      end

      def secure_boot_widget?
        Systeminfo.secure_boot_available?(systemdboot.name)
      end

      def pmbr_widget?
        Pmbr.available?
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
            BlsWidget::TimeoutWidget.new,
            HSpacing(1)
          ),
          VStretch()
        )
      end
    end
  end
end
