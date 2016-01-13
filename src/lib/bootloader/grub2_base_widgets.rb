require "yast"

require "bootloader/generic_widgets"

Yast.import "Initrd"
Yast.import "Label"
Yast.import "Report"
Yast.import "UI"

module Bootloader
  class Grub2BaseWidgets < GenericWidgets
    class << self
      def description
        textdomain "bootloader"

        widgets

        own = {
          "vgamode"     => {
            "widget" => :combobox,
            "label"  => Ops.get(@grub2_descriptions, "vgamode", "vgamode"),
            "opt"    => [:editable, :hstretch],
            "init"   => fun_ref(method(:VgaModeInit), "void (string)"),
            "store"  => fun_ref(method(:StoreGlobalStr), "void (string, map)"),
            "help"   => Ops.get(@grub2_help_messages, "vgamode", "")
          },
          "pmbr"        => {
            "widget" => :combobox,
            "label"  => @grub2_descriptions["pmbr"],
            "opt"    => [],
            "init"   => fun_ref(method(:PMBRInit), "void (string)"),
            "store"  => fun_ref(method(:StorePMBR), "void (string, map)"),
            "help"   => @grub2_help_messages["pmbr"]
          },
          "default"     => {
            "widget" => :combobox,
            "label"  => Ops.get(@grub_descriptions, "default", "default"),
            "opt"    => [:editable, :hstretch],
            "init"   => fun_ref(method(:DefaultEntryInit), "void (string)"),
            "store"  => fun_ref(method(:StoreGlobalStr), "void (string, map)"),
            "help"   => Ops.get(@grub_help_messages, "default", "")
          },
          "console"     => {
            "widget"        => :custom,
            "custom_widget" => ConsoleContent(),
            "init"          => fun_ref(method(:ConsoleInit), "void (string)"),
            "store"         => fun_ref(
              method(:ConsoleStore),
              "void (string, map)"
            ),
            "handle"        => fun_ref(
              method(:ConsoleHandle),
              "symbol (string, map)"
            ),
            "handle_events" => [:browsegfx],
            "help"          => Ops.get(@grub_help_messages, "serial", "")
          },
        }

        own.merge(super)
      end
    end
  end

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
  end

  class TimeoutWidget < CWM::IntFieldWidget
    include Grub2Widget

    def initialize(hidden_menu_widget)
      textdomain "bootloader"

      self.widget_id = "timeout"

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

    def init(widget)
      if grub_default.hidden_timeout && grub_default.hidden_timeout > 0
        self.value = grub_default.hidden_timeout
      else
        self.value = grub_default.timeout
      end
    end

    def store(_widget, _event)
      if @hidden_menu_widget.checked?
        grub_default.hidden_timeout = value
        grub_default.timeout = 0
      else
        grub_default.hidden_timeout = 0
        grub_default.timeout = value
      end
    end
  end

  class ActivateWidget < CWM::CheckboxWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"

      self.widget_id = "activate"
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

    def init(widget)
      self.value = stage1.model.activate
    end

    def store(_widget, _event)
      stage1.model.activate = checked?
    end
  end

  class GenericMBRWidget < CWM::CheckboxWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"

      self.widget_id = "generic_mbr"
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

    def init(_widget)
      self.value = stage1.model.generic_mbr
    end

    def store(_widget, _event)
      stage1.model.generic_mbr = checked?
    end
  end

  class HiddenMenuWidget < CWM::CheckboxWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"

      self.widget_id = "hidden_menu"
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

    def init(_widget)
      self.value = default_grub.hidden_timeout && default_grub.hidden_timeout > 0
    end
  end

  class OSProberWidget < CWM::CheckboxWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"

      self.widget_id = "os_prober"
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

    def init(_widget)
      self.value = grub_default.os_prober.enabled?
    end

    def store(_widget, _event)
      grub_default.os_prober.value = checked?
    end
  end

  class KernelAppendWidget < CWM::InputFieldEntry
    include Grub2Widget

    def initialize
      textdomain "bootloader"

      self.widget_id = "kernel_append"
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

    def init(_widget)
      self.value = grub_default.kernel_params.serialize
    end

    def store(_widget, _event)
      grub_default.kernel_params.replace(value)
    end
  end

  class GrubPasswordWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"

      self.widget_id = "password"
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

    def validate(_widget, _event)
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

    def init(_widget)
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

    def handle(_widget, _event)
      return unless event["ID"] == :use_pas

      enabled = Yast::UI.QueryWidget(Id(:use_pas), :Value)
      Yast::UI.ChangeWidget(Id(:unrestricted_pw), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:pw1), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:pw2), :Enabled, enabled)

      nil
    end

    def store(_widget, _event)
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

      self.widget_id = "console"
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

    def init(_widget)
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

    def store(_widget, _event)
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

    def handle(_widget, event)
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
end
