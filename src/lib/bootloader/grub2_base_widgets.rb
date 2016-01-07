require "yast"

require "bootloader/generic_widgets"

module Bootloader
  class Grub2BaseWidgets < GenericWidgets
    class << self
      def description
        textdomain "bootloader"

        own = {
          "timeout"     => TimeoutWidget.new.description,
          "activate"    => CommonCheckboxWidget(
            Ops.get(@grub_descriptions, "activate", "activate"),
            Ops.get(@grub_help_messages, "activate", "")
          ),
          "generic_mbr" => CommonCheckboxWidget(
            Ops.get(@grub_descriptions, "generic_mbr", "generic mbr"),
            Ops.get(@grub_help_messages, "generic_mbr", "")
          ),
          "hiddenmenu"  => CommonCheckboxWidget(
            Ops.get(@grub_descriptions, "hiddenmenu", "hidden menu"),
            Ops.get(@grub_help_messages, "hiddenmenu", "")
          ),
          "os_prober"   => {
            "widget" => :checkbox,
            "label"  => @grub2_descriptions["os_prober"],
            "help"   => @grub2_help_messages["os_prober"],
            "init"   => fun_ref(method(:init_os_prober), "void (string)"),
            "store"  => fun_ref(method(:store_os_prober), "void (string, map)")
          },
          "append"      => {
            "widget" => :textentry,
            "label"  => @grub2_descriptions["append"],
            "help"   => @grub2_help_messages["append"],
            "init"   => fun_ref(method(:init_append), "void (string)"),
            "store"  => fun_ref(method(:store_append), "void (string, map)")
          },
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
          "password"    => {
            "widget"            => :custom,
            "custom_widget"     => passwd_content,
            "init"              => fun_ref(
              method(:grub2_pwd_init),
              "void (string)"
            ),
            "handle"            => fun_ref(
              method(:HandlePasswdWidget),
              "symbol (string, map)"
            ),
            "store"             => fun_ref(
              method(:grub2_pwd_store),
              "void (string, map)"
            ),
            "validate_type"     => :function,
            "validate_function" => fun_ref(
              method(:ValidatePasswdWidget),
              "boolean (string, map)"
            ),
            "help"              => @grub_help_messages["password"] || ""
          }
        }

        own.merge(super)
      end

    private

    end

    # Adds to generic widget grub2 specific helpers
    class Grub2Widget < WidgetBase

    protected

      def grub_default
        BootloaderFactory.current.grub_default
      end
    end

    class TimeoutWidget < Grub2Widget
      def description
        textdomain "bootloader"

        {
          "widget"  => :intfield,
          "label"   => _("&Timeout in Seconds"),
          "minimum" => -1,
          "maximum" => 600,
          "init"    => init_method,
          "store"   => store_method,
          "help"    => _("<p><b>Timeout in Seconds</b><br>\n" \
            "Specifies the time the bootloader will wait until the default kernel is loaded.</p>\n")

        }
      end

    private

      def init(widget)
        Yast::UI.ChangeWidget(Id(widget), :Value, grub_default.timeout)
      end

      def store(widget, _event)
        value = Yast::UI.QueryWidget(Id(widget), :Value)
        grub_default.timeout = value
      end
    end
  end
end
