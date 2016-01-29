require "yast"

require "bootloader/bootloader_factory"
require "bootloader/none_bootloader"
require "bootloader/grub2_widgets"

Yast.import "BootStorage"
Yast.import "CWMTab"
Yast.import "CWM"
Yast.import "Mode"
Yast.import "Popup"

module Bootloader
  # Dialog for whole bootloader configuration
  class ConfigDialog
    include Yast::Logger
    include Yast::I18n
    include Yast::UIShortcuts

    def run
      textdomain "bootloader"

      log.info "Running Main Dialog"

      # F#300779 - Install diskless client (NFS-root)
      # kokso: additional warning that root partition is nfs type -> bootloader will not be installed
      device = Yast::BootStorage.disk_with_boot_partition

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

      if BootloaderFactory.current.is_a?(NoneBootloader)
        contents = VBox(LoaderTypeWidget.new)
      else
        tabs = CWM::Tabs.new(BootCodeTab.new, KernelTab.new, BootloaderTab.new)
        contents = VBox(tabs)
      end

      Yast::CWM.show(
        contents,
        caption:        _("Boot Loader Settings"),
        back_button:    "",
        abort_button:   Yast::Label.CancelButton,
        next_button:    Yast::Label.OKButton,
        skip_store_for: [:redraw]
      )
    end
  end
end
