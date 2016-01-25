require "yast"

require "bootloader/generic_widgets"

Yast.import "Initrd"
Yast.import "Label"
Yast.import "Report"
Yast.import "UI"

module Bootloader
  # Adds to generic widget grub2 specific helpers
  module Grub2Widget

  protected

    def grub_default
      BootloaderFactory.current.grub_default
    end

    def stage1
      BootloaderFactory.current.stage1
    end

    def password
      BootloaderFactory.current.password
    end

    def sections
      BootloaderFactory.current.password
    end

    def grub2
      BootloaderFactory.current
    end
  end

  class TimeoutWidget < CWM::IntField
    include Grub2Widget

    def initialize(hidden_menu_widget)
      textdomain "bootloader"

      @minimum = -1
      @maximum = 600
      @hidden_menu_widget = hidden_menu_widget
    end

  private

    attr_reader :minimum, :maximum

    def label
      _("&Timeout in Seconds")
    end

    def help
      _("<p><b>Timeout in Seconds</b><br>\n" \
        "Specifies the time the bootloader will wait until the default kernel is loaded.</p>\n"
      )
    end

    def init
      if grub_default.hidden_timeout && grub_default.hidden_timeout > 0
        self.value = grub_default.hidden_timeout
      else
        self.value = grub_default.timeout
      end
    end

    def store
      if @hidden_menu_widget.checked?
        grub_default.hidden_timeout = value
        grub_default.timeout = 0
      else
        grub_default.hidden_timeout = 0
        grub_default.timeout = value
      end
    end
  end

  class ActivateWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def label
      _("Set &active Flag in Partition Table for Boot Partition")
    end

    def help
      _(
        "<p><b>Set active Flag in Partition Table for Boot Partition</b><br>\n" \
          "To activate the partition which contains the boot loader. The generic MBR code will then\n" \
          "boot the active partition. Older BIOSes require one partition to be active even\n" \
          "if the boot loader is installed in the MBR.</p>"
      )
    end

    def init
      self.value = stage1.model.activate
    end

    def store
      stage1.model.activate = checked?
    end
  end

  class GenericMBRWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def label
      _("Write &generic Boot Code to MBR")
    end

    def help
      _(
        "<p><b>Write generic Boot Code to MBR</b> replace the master boot" \
        " record of your disk with generic code (OS independent code which\n" \
        "boots the active partition).</p>"
      )
    end

    def init
      self.value = stage1.model.generic_mbr
    end

    def store
      stage1.model.generic_mbr = checked?
    end
  end

  class HiddenMenuWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def label
      _("&Hide Menu on Boot")
    end

    def help
      _(
        "<p>Selecting <b>Hide Menu on Boot</b> will hide the boot menu.</p>"
      )
    end

    def init
      self.value = default_grub.hidden_timeout && default_grub.hidden_timeout > 0
    end
  end

  class OSProberWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def label
      _("Probe Foreign OS")
    end

    def help
      _(
        "<p><b>Probe Foreign OS</b> by means of os-prober for multiboot with " \
          "other foreign distribution </p>"
      )
    end

    def init
      self.value = grub_default.os_prober.enabled?
    end

    def store
      grub_default.os_prober.value = checked?
    end
  end

  class KernelAppendWidget < CWM::InputField
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

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
      self.value = grub_default.kernel_params.serialize
    end

    def store
      grub_default.kernel_params.replace(value)
    end
  end

  class PMBRWidget < CWM::ComboBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def init
      self.value = grub2.pmbr_action
    end

    def items
      [
        # TRANSLATORS: set flag on disk
        [:add, _("set")],
        # TRANSLATORS: remove flag from disk
        [:remove, _("remove")],
        # TRANSLATORS: do not change flag on disk
        [:nothing, _("do not change")]
      ]
    end

    def store
      grub2.pmbr_action = value
    end
  end

  class GrubPasswordWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    MASKED_PASSWORD = "**********"

    def content
      HBox(
        CheckBoxFrame(
          Id(:use_pas),
          _("Prot&ect Boot Loader with Password"),
          true,
          VBox(
            HBox(
              HSpacing(2),
              # TRANSLATORS: checkbox entry
              CheckBox(Id(:unrestricted_pw), _("P&rotect Entry Modification Only")),
              HStretch()
            ),
            HBox(
              HSpacing(2),
              # text entry
              Password(Id(:pw1), Opt(:hstretch), _("&Password")),
              # text entry
              HSpacing(2),
              Password(Id(:pw2), Opt(:hstretch), _("Re&type Password")),
              HStretch()
            )
          )
        )
      )
    end

    def validate
      return true unless Yast::UI.QueryWidget(Id(:use_pas), :Value)
      if Yast::UI.QueryWidget(Id(:pw1), :Value) == ""
        Yast::Report.Error(_("The password must not be empty."))
        Yast::UI.SetFocus(Id(:pw1))
        return false
      end
      if Yast::UI.QueryWidget(Id(:pw1), :Value) == UI.QueryWidget(Id(:pw2), :Value)
        return true
      end
      Yast::Report.Error(_(
        "'Password' and 'Retype password'\ndo not match. Retype the password."
      ))
      Yast::UI.SetFocus(Id(:pw1))
      false
    end

    def init
      enabled = password.used?
      # read state on disk only if not already set by user (bnc#900026)
      value = enabled && password.password? ? MASKED_PASSWORD : ""

      UI.ChangeWidget(Id(:use_pas), :Value, enabled)
      UI.ChangeWidget(Id(:pw1), :Enabled, enabled)
      UI.ChangeWidget(Id(:pw1), :Value, value)
      UI.ChangeWidget(Id(:pw2), :Enabled, enabled)
      UI.ChangeWidget(Id(:pw2), :Value, value)
      UI.ChangeWidget(Id(:unrestricted_pw), :Enabled, enabled)
      UI.ChangeWidget(Id(:unrestricted_pw), :Value, password.unrestricted?)
    end

    def handle(event)
      return unless event["ID"] == :use_pas

      enabled = Yast::UI.QueryWidget(Id(:use_pas), :Value)
      Yast::UI.ChangeWidget(Id(:unrestricted_pw), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:pw1), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:pw2), :Enabled, enabled)

      nil
    end

    def store
      usepass = Yast::UI.QueryWidget(Id(:use_pas), :Value)
      if !usepass
        password.used = false
        return
      end

      password.used = true

      value = YAST::UI.QueryWidget(Id(:pw1), :Value)
      # special value as we do not know password, so it mean user do not change it
      password.password = value if value != MASKED_PASSWORD

      value = UI.QueryWidget(Id(:unrestricted_pw), :Value)
      password.unrestricted = value
    end

    def help
      _(
        "<p><b>Protect Boot Loader with Password</b><br>\n" \
          "At boot time, modifying or even booting any entry will require the" \
          " password. If <b>Protect Entry Modification Only</b> is checked then " \
          "booting any entry is not restricted but modifying entries requires " \
          "the password (which is the way GRUB 1 behaved).<br>" \
          "YaST will only accept the password if you repeat it in " \
          "<b>Retype Password</b>.</p>"
        )
    end
  end

  class ConsoleWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def content
      # TODO: simplify a bit content or split it
      VBox(
        CheckBoxFrame(
          Id(:gfxterm_frame),
          _("Use &graphical console"),
          true,
          HBox(
            HSpacing(2),
            ComboBox(
              Id(:gfxmode),
              Opt(:editable, :hstretch),
              _("&Console resolution"),
              [""]
            ),
            HBox(
              Left(
                InputField(
                  Id(:theme),
                  Opt(:hstretch),
                  _("&Console theme")
                )
              ),
              VBox(
                Left(Label("")),
                Left(
                  PushButton(
                    Id(:browsegfx),
                    Opt(:notify),
                    Yast::Label.BrowseButton
                  )
                )
              )
            ),
            HStretch()
          )
        ),
        CheckBoxFrame(
          Id(:console_frame),
          _("Use &serial console"),
          true,
          HBox(
            HSpacing(2),
            InputField(
              Id(:console_args),
              Opt(:hstretch),
              _("&Console arguments")
            ),
            HStretch()
          )
        )
      )
    end

    def init
      enable = grub_default.terminal == :serial
      Yast::UI.ChangeWidget(Id(:console_frame), :Value, enable)
      args = grub_default.serial_console || ""
      Yast::UI.ChangeWidget(Id(:console_args), :Value, args)

      enable = grub_default.terminal == :gfxterm
      Yast::UI.ChangeWidget(Id(:gfxterm_frame), :Value, enable)


      UI.ChangeWidget(Id(:gfxmode), :Items, vga_modes_items)
      mode = grub_default.gfxmode

      # there's mode specified, use it
      UI.ChangeWidget(Id(:gfxmode), :Value, mode) if mode && mode != ""

      UI.ChangeWidget(Id(:theme), :Value, grub_default.theme)
    end

    def vga_modes_items
      return @vga_modes if @vga_modes

      @vga_modes = Yast::Initrd.VgaModes

      @vga_modes.sort! do |a, b|
        res = a["width"] <=> b["width"]
        res = a["height"] <=> b["height"] if res == 0

        res
      end

      @vga_modes.map! { |a| "#{a["width"]}x#{a["height"]}" }
      @vga_modes.uniq!

      @vga_modes.map! { |m| Item(Id(m), m) }
      @vga_modes.unshift(Item(Id("auto"), _("Autodetect by grub2")))

      @vga_modes
    end

    def store
      use_serial = Yast::UI.QueryWidget(Id(:console_frame), :Value)
      use_gfxterm = Yast::UI.QueryWidget(Id(:gfxterm_frame), :Value)

      use_gfxterm = false if use_gfxterm && use_serial

      if use_serial
        console_value = Yast::UI.QueryWidget(Id(:console_args), :Value)
        BootloaderFactory.current.enable_serial_console(console_value)
      elsif use_gfxterm
        grub_default.terminal = :gfxterm
      else
        grub_default.terminal = :console
      end

      mode = Yast::UI.QueryWidget(Id(:gfxmode), :Value)
      grub_default.gfxmode = mode if mode != ""

      theme = Yast::UI.QueryWidget(Id(:theme), :Value)
      grub_default.theme = theme if theme != ""
    end

    def handle(event)
      return if event["ID"] != :browsegfx

      theme_dir = "/boot/grub2/themes/openSUSE"
      theme_dir = "/boot/grub2" unless ::Dir.exist?(theme_dir)

      file = Yast::UI.AskForExistingFile(
        theme_dir,
        "*.txt",
        _("Choose new graphical theme file")
      )

      Yast::UI.ChangeWidget(Id(:theme), :Value, file) if file

      nil
    end
  end

  class DefaultSectionWidget < CWM::ComboBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

  private

    def init
      self.value = sections.default
    end

    def list
      sections.all.map do |section|
        [section, section]
      end
    end

    def store
      sections.default = value
    end
  end

  class KernelTab < CWM::Tab
    def label
      textdomain "bootloader"

      _("kernel parameters")
    end

    def contents
      console_widget = Yast::Arch.s390 ? CWM::Empty.new("console") : ConsoleWidget.new
      VBox(
        VSpacing(1),
        MarginBox(1, 0.5, KernelAppendWidget.new),
        MarginBox(1, 0.5, console_widget),
        VStretch()
      )
    end
  end

  class BootCodeTab < CWM::Tab
    include Grub2Widget

    def initialize
      self.initial = true
    end

    def label
      textdomain "bootloader"

      _("boot code options")
    end

    def contents
      if Arch.s390 || Arch.aarch64
        loader_widget = CWM::Empty.new("loader_location")
      else
        # TODO: create widget
        loader_widget = CWM::Empty.new("loader_location")
      end

      if (Yast::Arch.x86_64 || Yast::Arch.i386) && grub2.name != "grub2-efi"
        activate_widget = ActivateWidget.new
        generic_mbr_widget = GenericMBRWidget.new
      else
        activate_widget = CWM::Empty.new("activate")
        generic_mbr_widget = CWM::Empty.new("generic_mbr")
      end

      # TODO: inst details
      inst_details_widget = CWM::Empty.new("inst_details")
      # TODO: PMbr detection if possible
      pmbr_widget = CWM::Empty.new("pmbr")

      VBox(
        VSquash(
          HBox(
            Top(VBox(VSpacing(1), LoaderTypeWidget.new)),
            loader_widget
          )
        ),
        MarginBox(1, 0.5, Left(activate_widget)),
        MarginBox(1, 0.5, Left(generic_mbr_widget)),
        MarginBox(1, 0.5, Left(pmbr_widget)),
        MarginBox(1, 0.5, Left(inst_details_widget)),
        VStretch()
      )
    end
  end

  class BootloaderTab < CWM::Tab
    def label
      textdomain "bootloader"

      _("Bootloader Options")
    end

    def contents
      VBox(
        VSpacing(2),
        HBox(
          HSpacing(1),
          TimeoutWidget.new,
          HSpacing(1),
          VBox(
            Left(Yast::Arch.s390 ? CWM::Empty.new("os_prober") : OSProberWidget.new),
            VSpacing(1),
            Left(HiddenMenuWidget.new)
          ),
          HSpacing(1)
        ),
        VSpacing(1),
        MarginBox(1, 1, DefaultSectionWidget.new),
        MarginBox(1, 1, GrubPasswordWidget.new),
        VStretch()
      )
    end
  end
end
