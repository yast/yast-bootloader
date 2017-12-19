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
      guarded_run
    rescue ::Bootloader::BrokenConfiguration => e
      ret = Yast::Report.AnyQuestion(_("Broken Configuration"),
        # TRANSLATORS: %s stands for readon why yast cannot process it
        _("YaST cannot process current bootloader configuration (%s). " \
          "Propose new configuration from scratch?") % e.reason,
        _("Propose"),
        _("Quit"),
        :yes) # focus proposing new one
      return :abort unless ret

      ::Bootloader::BootloaderFactory.current = ::Bootloader::BootloaderFactory.proposed
      ::Bootloader::BootloaderFactory.current.propose

      retry
    end

  private

    def guarded_run
      textdomain "bootloader"

      log.info "Running Main Dialog"

      # F#300779 - Install diskless client (NFS-root)
      # additional warning that root partition is nfs type -> bootloader will not be installed
      nfs = Yast::BootStorage.boot_mountpoint.is?(:nfs)

      if nfs && Yast::Mode.installation
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
