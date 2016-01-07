require "yast"

require "bootloader/bootloader_factory"

Yast.import "UI"
Yast.import "Popup"

module Bootloader
  class GlobalWidgets
    class << self
      include Yast::UIShortcuts
      include Yast::I18n

      # Description of widgets usable in CWM framework
      def description
        textdomain "bootloader"

        {
          "loader_type"    => {
            "widget"        => :custom,
            "custom_widget" => loader_content
            "init"        => fun_ref(method(:init_loader), "void (string)"),
            "handle"      => fun_ref(method(:loader_handle), "symbol (string, map)"),
            "help"        => loader_help
          }
        }
      end

    private

      # shortcut from Yast namespace to avoid including whole namespace
      # kill converts in CWM module, to avoid this workaround for funrefs
      def fun_ref(*args)
        Yast::FunRef.new(*args)
      end

      def init_loader(widget)
        Yast::UI.ChangeWidget(Id(widget), :Value, BootloaderFactory.current.name)
      end

      def loader_content
        ComboBox(
          Id("loader_type"),
          Opt(:notify),
          # combo box
          _("&Boot Loader"),
          BootloaderFactory.supported_names.map do |name|
            Item(Id(name), localized_names(name))
          end
        )
      end

      def localized_names(name)
        names = {
          "grub2" => _("GRUB2"),
          "grub2-efi" => _("GRUB2 for EFI"),
          # Translators: option in combo box when bootloader is not managed by yast2
          "none" => _("Not Managed"),
          "default" => _("Default")
        }

        names[name] or raise "Unknown supported bootloader '#{name}'"
      end

      def loader_handle(key, event)
        return if event["ID"] != key # can happen in fake CWM events

        old_bl = BootloaderFactory.current.name
        new_bl = Yast::UI.QueryWidget(Id(key), :Value)

        return nil if old_bl == new_bl

        if new_bl == "none"
          # popup - Continue/Cancel
          popup_msg = _(
            "\n" \
            "If you do not install any boot loader, the system\n" \
            "might not start.\n" \
            "\n" \
            "Proceed?\n"
          )

          if !Yast::Popup.ContinueCancel(popup_msg)
            return :redraw
          end
        end

        BootloaderFactory.current_name = new_bl
        :redraw
      end

      def loader_help
        _(
          "<p><b>Boot Loader Type</b><br>\n" \
            "To select whether to install a boot loader and which bootloader to install,\n" \
            "use <b>Boot Loader</b>.</p>"
        )
      end
    end
  end
end
