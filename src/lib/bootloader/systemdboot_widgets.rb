# frozen_string_literal: true

require "yast"
require "bootloader/generic_widgets"
require "bootloader/systeminfo"
require "bootloader/cpu_mitigations"

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
              systemdboot.menue_timeout.to_i),
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
        Yast::UI.ChangeWidget(Id(:cont_boot), :Value, systemdboot.menue_timeout >= 0)
        systemdboot.menue_timeout = default_value if systemdboot.menue_timeout < 0
        Yast::UI.ChangeWidget(Id(:seconds), :Value, systemdboot.menue_timeout)
      end

      def store
        cont_boot = Yast::UI.QueryWidget(Id(:cont_boot), :Value)
        systemdboot.menue_timeout = cont_boot ? Yast::UI.QueryWidget(Id(:seconds), :Value) : -1
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

    # Represents decision if smt is enabled
    class CpuMitigationsWidget < CWM::ComboBox

      def initialize
        textdomain "bootloader"

        super
      end

      def label
        _("CPU Mitigations")
      end

      def items
        ::Bootloader::CpuMitigations::ALL.map do |m|
          [m.value.to_s, m.to_human_string]
        end
      end

      def help
        _(
          "<p><b>CPU Mitigations</b><br>\n" \
          "The option selects which default settings should be used for CPU \n" \
          "side channels mitigations. A highlevel description is on our Technical Information \n" \
          "Document TID 7023836. Following options are available:<ul>\n" \
          "<li><b>Auto</b>: This option enables all the mitigations needed for your CPU model. \n" \
          "This setting can impact performance to some degree, depending on CPU model and \n" \
          "workload. It provides all security mitigations, but it does not protect against \n" \
          "cross-CPU thread attacks.</li>\n" \
          "<li><b>Auto + No SMT</b>: This option enables all the above mitigations in \n" \
          "\"Auto\", and also disables Simultaneous Multithreading to avoid \n" \
          "side channel attacks across multiple CPU threads. This setting can \n" \
          "further impact performance, depending on your \n" \
          "workload. This setting provides the full set of available security mitigations.</li>\n" \
          "<li><b>Off</b>: All CPU Mitigations are disabled. This setting has no performance \n" \
          "impact, but side channel attacks against your CPU are possible, depending on CPU \n" \
          "model.</li>\n" \
          "<li><b>Manual</b>: This setting does not specify a mitigation level and leaves \n" \
          "this to be the kernel default. The administrator can add other mitigations options \n" \
          "in the <i>kernel command line</i> widget.\n" \
          "All CPU mitigation specific options can be set manually.</li></ul></p>"
        )
      end

      def init
        self.value = systemdboot.cpu_mitigations.value.to_s
      end

      def store
        systemdboot.cpu_mitigations = ::Bootloader::CpuMitigations.new(value.to_sym) if enabled?
      end
    end

    # Represents decision if smt is enabled
    class CpuMitigationsWidget < CWM::ComboBox

      def initialize
        textdomain "bootloader"

        super
      end

      def label
        _("CPU Mitigations")
      end

      def items
        ::Bootloader::CpuMitigations::ALL.map do |m|
          [m.value.to_s, m.to_human_string]
        end
      end

      def help
        _(
          "<p><b>CPU Mitigations</b><br>\n" \
          "The option selects which default settings should be used for CPU \n" \
          "side channels mitigations. A highlevel description is on our Technical Information \n" \
          "Document TID 7023836. Following options are available:<ul>\n" \
          "<li><b>Auto</b>: This option enables all the mitigations needed for your CPU model. \n" \
          "This setting can impact performance to some degree, depending on CPU model and \n" \
          "workload. It provides all security mitigations, but it does not protect against \n" \
          "cross-CPU thread attacks.</li>\n" \
          "<li><b>Auto + No SMT</b>: This option enables all the above mitigations in \n" \
          "\"Auto\", and also disables Simultaneous Multithreading to avoid \n" \
          "side channel attacks across multiple CPU threads. This setting can \n" \
          "further impact performance, depending on your \n" \
          "workload. This setting provides the full set of available security mitigations.</li>\n" \
          "<li><b>Off</b>: All CPU Mitigations are disabled. This setting has no performance \n" \
          "impact, but side channel attacks against your CPU are possible, depending on CPU \n" \
          "model.</li>\n" \
          "<li><b>Manual</b>: This setting does not specify a mitigation level and leaves \n" \
          "this to be the kernel default. The administrator can add other mitigations options \n" \
          "in the <i>kernel command line</i> widget.\n" \
          "All CPU mitigation specific options can be set manually.</li></ul></p>"
        )
      end

      def init
        self.value = systemdboot.cpu_mitigations.value.to_s
      end

      def store
        systemdboot.cpu_mitigations = ::Bootloader::CpuMitigations.new(value.to_sym) if enabled?
      end
    end

    # represents kernel command line
    class KernelAppendWidget < CWM::InputField
      include SystemdBootHelper      

      def initialize
        textdomain "bootloader"

        super
      end

      def label
        _("O&ptional Kernel Command Line Parameter")
      end

      def help
        _(
          "<p><b>Optional Kernel Command Line Parameter</b> lets you define " \
          "additional parameters to pass to the kernel.</p>"
        )
      end

      def init
        self.value = systemdboot.kernel_params.serialize.gsub(/mitigations=\S+/, "")
      end

      def store
        systemdboot.kernel_params.replace(value)
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

      def horizontal_margin
        @horizontal_margin ||= Yast::UI.TextMode ? 1 : 1.5
      end

      def secure_boot_widget?
        Systeminfo.secure_boot_available?(systemdboot.name)
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
