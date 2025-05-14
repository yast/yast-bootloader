# frozen_string_literal: true

require "yast"

require "bootloader/bootloader_factory"
require "bootloader/cpu_mitigations"

require "cwm/widget"

Yast.import "UI"
Yast.import "Popup"

module Bootloader
  # Widget to switch between all supported bootloaders
  class LoaderTypeWidget < CWM::ComboBox
    def initialize
      textdomain "bootloader"

      super
    end

    def label
      textdomain "bootloader"

      _("&Boot Loader")
    end

    def init
      self.value = BootloaderFactory.current.name
    end

    def opt
      [:notify]
    end

    def items
      BootloaderFactory.supported_names.map do |name|
        [name, localized_names(name)]
      end
    end

    def localized_names(name)
      names = {
        "grub2"        => _("GRUB2"),
        "grub2-efi"    => _("GRUB2 for EFI"),
        # Translators: Using Boot Loader Specification (BLS) snippets.
        "grub2-bls"    => _("GRUB2 with BLS"),
        "systemd-boot" => _("Systemd Boot"),
        # Translators: option in combo box when bootloader is not managed by yast2
        "none"         => _("Not Managed"),
        "default"      => _("Default")
      }

      names[name] or raise "Unknown supported bootloader '#{name}'"
    end

    def handle
      old_bl = BootloaderFactory.current.name
      new_bl = value

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

        return :redraw if !Yast::Popup.ContinueCancel(popup_msg)
      end

      if !Yast::Stage.initial && ["systemd-boot", "grub2-bls"].include?(old_bl)
        Yast::Popup.Warning(format(_(
        "Switching from %s to another bootloader\n" \
        "is currently not supported.\n"
      ), old_bl))
        return :redraw
      end

      if !Yast::Stage.initial && ["systemd-boot", "grub2-bls"].include?(new_bl)
        Yast::Popup.Warning(format(_(
        "Switching to bootloader %s \n" \
        "is currently not supported.\n"
      ), new_bl))
        return :redraw
      end

      BootloaderFactory.current_name = new_bl
      BootloaderFactory.current.propose

      :redraw
    end

    def help
      _(
        "<p><b>Boot Loader</b>\n" \
        "specifies which boot loader to install. Can be also set to <tt>None</tt> " \
        "which means that the boot loader configuration is not managed by YaST and also " \
        "the kernel post install script does not update the boot loader configuration."
      )
    end
  end

  # represent choosing default section to boot
  class DefaultSectionWidget < CWM::ComboBox
    def initialize
      textdomain "bootloader"

      super
    end

    def label
      _("&Default Boot Section")
    end

    def help
      _(
        "<p><b>Default Boot Section</b> selects the default section for booting.\n" \
        " If sections are not generated yet ( e.g. during installation) \n" \
        "then the box is empty and the default is picked by grub2 itself.</p>\n"
      )
    end

    def init
      self.value = Bootloader::BootloaderFactory.current.sections.default
    end

    def items
      Bootloader::BootloaderFactory.current.sections.all.map do |section|
        [section, section]
      end
    end

    def store
      Bootloader::BootloaderFactory.current.sections.default = value
    end
  end

  # Represents switcher for secure boot on EFI
  class SecureBootWidget < CWM::CheckBox
    def initialize
      textdomain "bootloader"

      super
    end

    def label
      _("&Secure Boot Support")
    end

    def help
      if Yast::Arch.s390
        _(
          "<p><b>Secure Boot Support</b> if checked enables Secure Boot support.<br>" \
          "This does not turn on secure booting. " \
          "It only switches to the new secure-boot enabled boot data format. " \
          "Note that this new format works only on z15 or later and "\
          "only for some disk types. " \
          "For more details see the requirements at  " \
          "https://www.ibm.com/docs/en/linux-on-systems?topic=introduction-requirements</p>"
        )
      else
        _(
          "<p><b>Secure Boot Support</b> if checked enables Secure Boot support.<br>" \
          "This does not turn on secure booting. " \
          "It only sets up the boot loader in a way that supports secure booting. " \
          "You still have to enable Secure Boot in the UEFI Firmware.</p> "
        )
      end
    end

    def init
      self.value = Bootloader::BootloaderFactory.current.secure_boot
    end

    def store
      Bootloader::BootloaderFactory.current.secure_boot = value
    end

    def validate
      return true if Yast::Mode.config ||
        !Yast::Arch.s390 ||
        !value ||
        value == Systeminfo.secure_boot_active?

      Yast::Popup.ContinueCancel(
        # text is identical like one in proposal client. Keep in sync!
        # TRANSLATORS: IPL stands for Initial Program Load, IBM speak for system boot
        _(
          "Secure boot IPL has the following minimum system requirements,\n" \
          "depending on the boot device to be IPLed:\n" \
          "NVMe disk: IBM LinuxONE III or newer.\n" \
          "FC-attached SCSI disk: IBM LinuxONE III, IBM z15 or newer.\n" \
          "ECKD DASD with CDL layout: IBM z16, LinuxONE 4 or newer.\n" \
          "If these requirements are not met, the system can be IPLed in non-secure mode only."
        )
      )
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
      if Bootloader::BootloaderFactory.current.respond_to?(:cpu_mitigations)
        self.value = Bootloader::BootloaderFactory.current.cpu_mitigations.value.to_s
      else
        disable
      end
    end

    def store
      return unless enabled?

      Bootloader::BootloaderFactory.current.cpu_mitigations =
        ::Bootloader::CpuMitigations.new(value.to_sym)
    end
  end

  # Represents Protective MBR action
  class PMBRWidget < CWM::ComboBox
    def initialize
      textdomain "bootloader"

      super
    end

    def label
      _("&Protective MBR flag")
    end

    def help
      _(
        "<p><b>Protective MBR flag</b> is expert only settings, that is needed " \
        "only on exotic hardware. For details see Protective MBR in GPT disks. " \
        "Do not touch if you are not sure.</p>"
      )
    end

    def init
      current_bl = ::Bootloader::BootloaderFactory.current
      if current_bl.respond_to?(:pmbr_action)
        self.value = current_bl.pmbr_action
      else
        log.error("Bootloader #{current_bl} does not support PMBR.")
        disable
      end
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
      current_bl = ::Bootloader::BootloaderFactory.current
      if current_bl.respond_to?(:pmbr_action)
        current_bl.pmbr_action = value
      else
        log.error("Bootloader #{current_bl} does not support PMBR.")
      end
    end
  end

  # represents kernel command line
  class KernelAppendWidget < CWM::InputField
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
      current_bl = ::Bootloader::BootloaderFactory.current
      case current_bl
      when ::Bootloader::SystemdBoot
        self.value = current_bl.kernel_params.serialize.gsub(/mitigations=\S+/, "")
      when ::Bootloader::Grub2Base
        self.value = current_bl.grub_default.kernel_params.serialize.gsub(/mitigations=\S+/, "")
      else
        disable
      end
    end

    def store
      return unless enabled?

      current_bl = ::Bootloader::BootloaderFactory.current
      case current_bl
      when ::Bootloader::SystemdBoot
        current_bl.kernel_params.replace(value)
      when ::Bootloader::Grub2Base
        current_bl.grub_default.kernel_params.replace(value)
      else
        log.error("Bootloader type #{current_bl} not found.")
      end
    end
  end
end
