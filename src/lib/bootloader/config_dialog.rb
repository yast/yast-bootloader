require "yast"

require "bootloader/bootloader_factory"
require "bootloader/none_bootloader"

Yast.import "BootCommon"
Yast.import "CWMTab"
Yast.import "CWM"
Yast.import "Mode"
Yast.import "Popup"

module Bootloader
  class ConfigDialog
    include Yast::Logger
    include Yast::I18n

    def run
      textdomain "bootloader"

      log.info "Running Main Dialog"

      # F#300779 - Install diskless client (NFS-root)
      # kokso: additional warning that root partition is nfs type -> bootloader will not be installed
      device = Yast::BootCommon.getBootDisk

      if device == "/dev/nfs" && Yast::Mode.installation
        Yast::Popup.Message(
          _(
            "The boot partition is of type NFS. Bootloader cannot be installed."
          )
        )
        log.info "Boot partition is nfs type, bootloader will not be installed."
        return :next
      end
      # F#300779: end


      widget_descr = Builtins.union(CommonGlobalWidgets(), Bootloader.blWidgetMaps)
      if BootloaderFactory.current.is_a?(NoneBootloader)
        contents = VBox("loader_type")
        widget_names = ["loader_type"]
      else
        contents = VBox("tab")
        widget_names = ["tab"]
        widget_descr["tab"] = Yast::CWMTab.CreateWidget(
          "tab_order"    => ["boot_code_tab", "kernel_tab", "bootloader_tab"],
          "tabs"         => Grub2TabDescr(),
          "widget_descr" => widget_descr,
          "initial_tab"  => "boot_code_tab",
          "no_help"      => ""
        )
      end



      # dialog caption
      caption = _("Boot Loader Settings")
      Yast::CWM.ShowAndRun(
        "widget_descr"       => widget_descr,
        "widget_names"       => widget_names,
        "contents"           => contents,
        "caption"            => caption,
        "back_button"        => "",
        "abort_button"       => Yast::Label.CancelButton,
        "next_button"        => Yast::Label.OKButton,
      )
    end
  end
end
