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

    # param initial_tab [:boot_code|:kernel|:bootloader] initial tab when dialog open
    def initialize(initial_tab: :boot_code)
      @initial_tab = initial_tab
    end

    def run
      guarded_run
    rescue ::Bootloader::NoRoot
      Yast::Report.Error(
        _("YaST cannot configure the bootloader because it failed to find the root file system.")
      )
      :abort
    rescue ::Bootloader::BrokenConfiguration, ::Bootloader::UnsupportedOption => e
      msg = if e.is_a?(::Bootloader::BrokenConfiguration)
        # TRANSLATORS: %s stands for readon why yast cannot process it
        _("YaST cannot process current bootloader configuration (%s). " \
          "Propose new configuration from scratch?") % e.reason
      else
        e.message
      end

      ret = Yast::Report.AnyQuestion(_("Unsupported Configuration"),
        msg,
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
      nfs = Yast::BootStorage.boot_filesystem.is?(:nfs)

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

      Yast::CWM.show(
        contents,
        caption:        _("Boot Loader Settings"),
        back_button:    "",
        abort_button:   Yast::Label.CancelButton,
        next_button:    Yast::Label.OKButton,
        skip_store_for: [:redraw]
      )
    end

    def contents
      return VBox(LoaderTypeWidget.new) if BootloaderFactory.current.is_a?(NoneBootloader)

      boot_code_tab = BootCodeTab.new
      kernel_tab = KernelTab.new
      bootloader_tab = BootloaderTab.new
      case @initial_tab
      when :boot_code then boot_code_tab.initial = true
      when :kernel then kernel_tab.initial = true
      when :bootloader then bootloader_tab.initial = true
      else
        raise "unknown initial tab #{@initial_tab.inspect}"
      end

      VBox(CWM::Tabs.new(boot_code_tab, kernel_tab, bootloader_tab))
    end
  end
end
