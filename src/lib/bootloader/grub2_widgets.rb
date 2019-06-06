require "yast"

require "bootloader/generic_widgets"
require "bootloader/device_map_dialog"
require "bootloader/serial_console"
require "bootloader/cpu_mitigations"
require "cfa/matcher"

Yast.import "BootStorage"
Yast.import "Initrd"
Yast.import "Label"
Yast.import "Report"
Yast.import "UI"
Yast.import "Mode"

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
      BootloaderFactory.current.sections
    end

    def grub2
      BootloaderFactory.current
    end
  end

  # Represents bootloader timeout value
  class TimeoutWidget < CWM::IntField
    include Grub2Widget

    def initialize(hidden_menu_widget)
      textdomain "bootloader"

      @minimum = -1
      @maximum = 600
      @hidden_menu_widget = hidden_menu_widget
    end

    attr_reader :minimum, :maximum

    def label
      _("&Timeout in Seconds")
    end

    def help
      _("<p><b>Timeout in Seconds</b>\n" \
        "specifies the time the boot loader will wait until the default kernel is loaded.</p>\n")
    end

    def init
      self.value = if grub_default.hidden_timeout && grub_default.hidden_timeout.to_i > 0
        grub_default.hidden_timeout.to_i
      else
        grub_default.timeout.to_i
      end
    end

    def store
      if @hidden_menu_widget.checked?
        grub_default.hidden_timeout = value.to_s
        grub_default.timeout = "0"
      else
        grub_default.hidden_timeout = "0"
        grub_default.timeout = value.to_s
      end
    end
  end

  # Represents decision if bootloader need activated partition
  class ActivateWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def label
      _("Set &active Flag in Partition Table for Boot Partition")
    end

    def help
      _(
        "<p><b>Set Active Flag in Partition Table for Boot Partition</b>\n" \
          "specifies whether the partition containing " \
          "the boot loader will have the \"active\" flag." \
          " The generic MBR code will then\n" \
          "boot the active partition. Older BIOSes require one partition to be active even\n" \
          "if the boot loader is installed in the MBR.</p>"
      )
    end

    def init
      self.value = stage1.activate?
    end

    def store
      stage1.activate = checked?
    end
  end

  # Represents decision if smt is enabled
  class CpuMitigationsWidget < CWM::ComboBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def label
      _("CPU Mitigations")
    end

    def items
      ::Bootloader::CpuMitigations::ALL.map do |m|
        [m.value, m.to_human_string]
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
      self.value = grub2.cpu_mitigations.value
    end

    def store
      grub2.cpu_mitigations = ::Bootloader::CpuMitigations.new(value)
    end
  end

  # Represents decision if generic MBR have to be installed on disk
  class GenericMBRWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

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
      self.value = stage1.generic_mbr?
    end

    def store
      stage1.generic_mbr = checked?
    end
  end

  # Represents decision if menu should be hidden or visible
  class HiddenMenuWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def label
      _("&Hide Menu on Boot")
    end

    def help
      _(
        "<p>Selecting <b>Hide Menu on Boot</b> will hide the boot menu.</p>"
      )
    end

    def init
      self.value = grub_default.hidden_timeout && grub_default.hidden_timeout.to_i > 0
    end
  end

  # Represents if os prober should be run
  class OSProberWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def label
      _("Pro&be Foreign OS")
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

  # represents kernel command line
  class KernelAppendWidget < CWM::InputField
    include Grub2Widget

    def initialize
      textdomain "bootloader"
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
      self.value = grub_default.kernel_params.serialize.gsub(/mitigations=\S+/, "")
    end

    def store
      grub_default.kernel_params.replace(value)
    end
  end

  # Represents Protective MBR action
  class PMBRWidget < CWM::ComboBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
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

  # Represents switcher for secure boot on EFI
  class SecureBootWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def label
      _("Enable &Secure Boot Support")
    end

    def help
      _("<p><b>Enable Secure Boot Support</b> if checked enables UEFI Secure Boot support.</p>")
    end

    def init
      self.value = grub2.secure_boot
    end

    def store
      grub2.secure_boot = value
    end
  end

  # Represents switcher for Trusted Boot
  class TrustedBootWidget < CWM::CheckBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def label
      _("Enable &Trusted Boot Support")
    end

    def help
      # TRANSLATORS: TrustedGRUB2 is a name, don't translate it
      res = _("<p><b>Trusted Boot</b> will install TrustedGRUB2\n" \
          "instead of regular GRUB2.\n" \
          "It means measuring the integrity of the boot process,\n" \
          "with the help from the hardware (a TPM, Trusted Platform Module,\n" \
          "chip).\n")
      if grub2.name == "grub2"
        res += _("First you need to make sure Trusted Boot is enabled in the BIOS\n" \
          "setup (the setting may be named \"Security Chip\", for example).\n")
      end

      res += "</p>"

      res
    end

    def init
      self.value = grub2.trusted_boot
    end

    def store
      grub2.trusted_boot = value
    end

    def validate
      return true if Yast::Mode.config || !value || grub2.name == "grub2-efi"
      tpm_files = Dir.glob("/sys/**/pcrs")
      if !tpm_files.empty?
        # check for file size does not work, since FS reports it 4096
        # even if the file is in fact empty and a single byte cannot
        # be read, therefore testing real reading (details: bsc#994556)
        return true unless File.read(tpm_files[0], 1).nil?
      end
      Yast::Popup.ContinueCancel(_("Trusted Platform Module not found.\n" \
                                   "Make sure it is enabled in BIOS.\n" \
                                   "The system will not boot otherwise."))
    end
  end

  # Represents grub password protection widget
  class GrubPasswordWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    MASKED_PASSWORD = "**********".freeze

    def contents
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
              # TRANSLATORS: text entry, please keep it short
              Password(Id(:pw1), Opt(:hstretch), _("&Password for GRUB2 User 'root'")),
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
      if Yast::UI.QueryWidget(Id(:pw1), :Value) == Yast::UI.QueryWidget(Id(:pw2), :Value)
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

      Yast::UI.ChangeWidget(Id(:use_pas), :Value, enabled)
      Yast::UI.ChangeWidget(Id(:pw1), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:pw1), :Value, value)
      Yast::UI.ChangeWidget(Id(:pw2), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:pw2), :Value, value)
      Yast::UI.ChangeWidget(Id(:unrestricted_pw), :Enabled, enabled)
      Yast::UI.ChangeWidget(Id(:unrestricted_pw), :Value, password.unrestricted?)
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
      matcher = CFA::Matcher.new(key: "rd.shell")
      grub_default.kernel_params.remove_parameter(matcher)
      if !usepass
        password.used = false
        return
      end

      password.used = true

      value = Yast::UI.QueryWidget(Id(:pw1), :Value)
      # special value as we do not know password, so it mean user do not change it
      password.password = value if value != MASKED_PASSWORD

      value = Yast::UI.QueryWidget(Id(:unrestricted_pw), :Value)
      grub_default.kernel_params.add_parameter("rd.shell", "0") if value
      password.unrestricted = value
    end

    def help
      _(
        "<p><b>Protect Boot Loader with Password</b>\n" \
          "at boot time, modifying or even booting any entry will require the" \
          " password. If <b>Protect Entry Modification Only</b> is checked then " \
          "booting any entry is not restricted but modifying entries requires " \
          "the password (which is the way GRUB 1 behaved). As side-effect of " \
          "this option, rd.shell=0 is added to kernel parameters, to prevent " \
          "an unauthorized access to the initrd shell. " \
          "YaST will only accept the password if you repeat it in " \
          "<b>Retype Password</b>. The password applies to the GRUB2 user 'root' " \
          "which is distinct from the Linux 'root'. YaST currently does not support " \
          "other GRUB2 users. If you need them, use a separate GRUB2 script.</p>"
      )
    end
  end

  # Represents graphical and serial console setup for bootloader
  #
  # Allows to configure terminal for grub. It can configure grub
  # to use either graphical terminal, console or console over serial line.
  #
  # Graphical or serial terminal has to be selected explicitly. Either
  # one of them or both at once.
  # Native console is configured as a fallback when nothing else is selected.
  class ConsoleWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def contents
      VBox(
        graphical_console_frame,
        serial_console_frame
      )
    end

    def help
      # Translators: do not translate the quoted parts like "unit"
      _(
        "<p><b>Use graphical console</b> when checked it allows to use various " \
        "display resolutions. The <tt>auto</tt> option tries to find " \
        "the best one when booting starts.</p>\n" \
        "<p><b>Use serial console</b> when checked it redirects the boot output " \
        "to a serial device like <tt>ttyS0</tt>. " \
        "At least the <tt>--unit</tt> option has to be specified, " \
        "and the complete syntax is <tt>%s</tt>. " \
        "Other parts are optional and if not set, a default is used. " \
        "<tt>NUM</tt> in commands stands for a positive number like 8. " \
        "Example parameters are <tt>serial --speed=38400 --unit=0</tt>.</p>"
      ) % syntax
    end

    def init
      init_console
      init_gfxterm

      Yast::UI.ChangeWidget(Id(:theme), :Value, grub_default.theme || "")
    rescue RuntimeError
      raise ::Bootloader::UnsupportedOption, "GRUB_TERMINAL"
    end

    def validate
      if Yast::UI.QueryWidget(Id(:console_frame), :Value)
        console_value = Yast::UI.QueryWidget(Id(:console_args), :Value)
        if console_value.strip.empty?
          Yast::Report.Error(
            _("To enable serial console you must provide the corresponding arguments.")
          )
          Yast::UI.SetFocus(Id(:console_args))
          return false
        end
        if ::Bootloader::SerialConsole.load_from_console_args(console_value).nil?
          # Translators: do not translate "unit"
          msg = _("To enable the serial console you must provide the corresponding arguments.\n" \
          "The \"unit\" argument is required, the complete syntax is:\n%s") % syntax
          Yast::Report.Error(msg)
          Yast::UI.SetFocus(Id(:console_args))
          return false
        end
      end
      true
    end

    def store
      use_serial = Yast::UI.QueryWidget(Id(:console_frame), :Value)
      use_gfxterm = Yast::UI.QueryWidget(Id(:gfxterm_frame), :Value)
      use_console = !use_serial && !use_gfxterm

      grub_default.terminal = []
      grub_default.terminal = [:gfxterm] if use_gfxterm

      if use_serial
        console_value = Yast::UI.QueryWidget(Id(:console_args), :Value)
        BootloaderFactory.current.enable_serial_console(console_value)
      elsif use_console
        grub_default.terminal = [:console]
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

  private

    # Initializates serial console specific widgets
    def init_console
      enable = grub_default.terminal.include?(:serial) if grub_default.terminal
      Yast::UI.ChangeWidget(Id(:console_frame), :Value, enable)
      args = grub_default.serial_console || ""
      Yast::UI.ChangeWidget(Id(:console_args), :Value, args)
    end

    # Initializates gfxterm specific widgets
    def init_gfxterm
      enable = grub_default.terminal.include?(:gfxterm) if grub_default.terminal
      Yast::UI.ChangeWidget(Id(:gfxterm_frame), :Value, enable)

      Yast::UI.ChangeWidget(Id(:gfxmode), :Items, vga_modes_items)
      mode = grub_default.gfxmode

      # there's mode specified, use it
      Yast::UI.ChangeWidget(Id(:gfxmode), :Value, mode) if mode && mode != ""
    end

    # Explanation for help and error messages
    def syntax
      # Translators: NUM is an abbreviation for "number",
      # to be substituted in a command like
      # "serial --unit=NUM --speed=NUM --parity={odd|even|no} --word=NUM --stop=NUM"
      # so do not use punctuation
      n = _("NUM")
      "serial --unit=#{n} --speed=#{n} --parity={odd|even|no} --word=#{n} --stop=#{n}"
    end

    def graphical_console_frame
      CheckBoxFrame(
        Id(:gfxterm_frame),
        _("Use &graphical console"),
        true,
        HBox(
          HSpacing(2),
          ComboBox(
            Id(:gfxmode), Opt(:editable, :hstretch), _("&Console resolution")
          ),
          HBox(
            Left(
              InputField(
                Id(:theme), Opt(:hstretch), _("&Console theme")
              )
            ),
            VBox(
              Left(Label("")),
              Left(
                PushButton(Id(:browsegfx), Opt(:notify), Yast::Label.BrowseButton)
              )
            )
          ),
          HStretch()
        )
      )
    end

    def vga_modes_items
      return @vga_modes if @vga_modes

      @vga_modes = Yast::Initrd.VgaModes

      @vga_modes.sort! do |a, b|
        res = a["width"] <=> b["width"]
        res = a["height"] <=> b["height"] if res.zero?

        res
      end

      @vga_modes.map! { |a| "#{a["width"]}x#{a["height"]}" }
      @vga_modes.uniq!

      @vga_modes.map! { |m| Item(Id(m), m) }
      @vga_modes.unshift(Item(Id("auto"), _("Autodetect by grub2")))

      @vga_modes
    end

    def serial_console_frame
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
    end
  end

  # represent choosing default section to boot
  class DefaultSectionWidget < CWM::ComboBox
    include Grub2Widget

    def initialize
      textdomain "bootloader"
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
      self.value = sections.default
    end

    def items
      sections.all.map do |section|
        [section, section]
      end
    end

    def store
      sections.default = value
    end
  end

  # Represents stage1 location for bootloader
  class LoaderLocationWidget < CWM::CustomWidget
    include Grub2Widget

    def contents
      textdomain "bootloader"

      VBox(
        Frame(
          _("Boot Loader Location"),
          HBox(
            HSpacing(1),
            VBox(*location_checkboxes),
            HSpacing(1)
          )
        ),
        VSpacing(1)
      )
    end

    def handle(event)
      return unless event["ID"] == :custom

      checked = Yast::UI.QueryWidget(Id(:custom), :Value)
      Yast::UI.ChangeWidget(Id(:custom_list), :Enabled, checked)

      nil
    end

    def init
      if locations.include?(:boot)
        Yast::UI.ChangeWidget(Id(:boot), :Value, stage1.boot_partition?)
      end
      Yast::UI.ChangeWidget(Id(:mbr), :Value, stage1.mbr?) if locations.include?(:mbr)

      init_custom_devices(stage1.custom_devices)
    end

    def store
      stage1.clear_devices
      locations.each do |id|
        next unless Yast::UI.QueryWidget(Id(id), :Value)

        case id
        when :boot
          stage1.boot_partition_names.each { |d| stage1.add_udev_device(d) }
        when :mbr
          stage1.boot_disk_names.each { |d| stage1.add_udev_device(d) }
        end
      end

      return unless Yast::UI.QueryWidget(:custom, :Value)

      devs = Yast::UI.QueryWidget(:custom_list, :Value)
      devs.split(",").each do |dev|
        # Add it exactly as specified by the user
        stage1.add_device(dev.strip)
      end
    end

    def validate
      if Yast::UI.QueryWidget(:custom, :Value)
        devs = Yast::UI.QueryWidget(:custom_list, :Value)
        if devs.strip.empty?
          Yast::Report.Error(_("Custom boot device have to be specied if checked"))
          Yast::UI.SetFocus(Id(:custom_list))
          return false
        end
      end

      true
    end

  private

    def init_custom_devices(custom_devices)
      if custom_devices.empty?
        Yast::UI.ChangeWidget(:custom, :Value, false)
        Yast::UI.ChangeWidget(:custom_list, :Enabled, false)
      else
        Yast::UI.ChangeWidget(:custom, :Value, true)
        Yast::UI.ChangeWidget(:custom_list, :Enabled, true)
        Yast::UI.ChangeWidget(:custom_list, :Value, custom_devices.join(","))
      end
    end

    def locations
      @locations ||= stage1.available_locations
    end

    def location_checkboxes
      checkboxes = []
      checkboxes << checkbox(:boot, _("Boo&t from Partition")) if locations.include?(:boot)
      checkboxes << checkbox(:mbr, _("Boot from &Master Boot Record")) if locations.include?(:mbr)

      checkboxes.concat(custom_partition_content)
    end

    def checkbox(id, title)
      Left(CheckBox(Id(id), title))
    end

    def custom_partition_content
      [
        Left(CheckBox(Id(:custom), Opt(:notify), _("C&ustom Boot Partition"))),
        Left(InputField(Id(:custom_list), Opt(:hstretch), ""))
      ]
    end
  end

  # Represents button that open Device Map edit dialog
  class DeviceMapWidget < ::CWM::PushButton
    include Grub2Widget

    def label
      textdomain "bootloader"

      _("&Edit Disk Boot Order")
    end

    def help
      textdomain "bootloader"

      _(
        "<p><b>Edit Disk Boot Order</b>\n" \
          "allows to specify the order of the disks according to the order in BIOS. Use\n" \
          "the <b>Up</b> and <b>Down</b> buttons to reorder the disks.\n" \
          "To add a disk, push <b>Add</b>.\n" \
          "To remove a disk, push <b>Remove</b>.</p>"
      )
    end

    def handle
      DeviceMapDialog.run(grub2.device_map)

      nil
    end
  end

  # represents Tab with kernel related configuration
  class KernelTab < CWM::Tab
    def label
      textdomain "bootloader"

      _("&Kernel Parameters")
    end

    def contents
      console_widget = Yast::Arch.s390 ? CWM::Empty.new("console") : ConsoleWidget.new
      VBox(
        VSpacing(1),
        MarginBox(1, 0.5, KernelAppendWidget.new),
        MarginBox(1, 0.5, Left(CpuMitigationsWidget.new)),
        MarginBox(1, 0.5, console_widget),
        VStretch()
      )
    end
  end

  # Represent tab with options related to stage1 location and bootloader type
  class BootCodeTab < CWM::Tab
    include Grub2Widget

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
        VSpacing(1),
        pmbr_widget,
        device_map_button,
        VStretch()
      )
    end

  private

    def widgets
      w = []
      w << LoaderLocationWidget.new if loader_location_widget?

      if generic_mbr_widget?
        w << ActivateWidget.new
        w << GenericMBRWidget.new
      end

      w << SecureBootWidget.new if secure_boot_widget?
      w << TrustedBootWidget.new if trusted_boot_widget?

      w.map do |widget|
        MarginBox(horizontal_margin, 0, Left(widget))
      end
    end

    def pmbr_widget
      return Empty() unless pmbr_widget?

      MarginBox(1, 0, Left(PMBRWidget.new))
    end

    def device_map_button
      return Empty() unless device_map_button?

      MarginBox(1, 0, Left(DeviceMapWidget.new))
    end

    def horizontal_margin
      @horizontal_margin ||= Yast::UI.TextMode ? 1 : 1.5
    end

    def loader_location_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.ppc) && grub2.name == "grub2"
    end

    def generic_mbr_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386) && grub2.name != "grub2-efi"
    end

    def secure_boot_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.aarch64) && grub2.name == "grub2-efi"
    end

    def trusted_boot_widget?
      return false if !(Yast::Arch.x86_64 || Yast::Arch.i386)
      return true if grub2.name == "grub2"
      # for details about grub2 efi trusted boot support see FATE#315831
      return File.exist?("/dev/tpm0") if grub2.name == "grub2-efi"
      false
    end

    def pmbr_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386) &&
        Yast::BootStorage.gpt_boot_disk?
    end

    def device_map_button?
      (Yast::Arch.x86_64 || Yast::Arch.i386) && grub2.name != "grub2-efi"
    end
  end

  # Represents bootloader specific options like its timeout, default section or password protection
  class BootloaderTab < CWM::Tab
    def label
      textdomain "bootloader"

      _("Boot&loader Options")
    end

    def contents
      hiden_menu_widget = HiddenMenuWidget.new
      VBox(
        VSpacing(2),
        HBox(
          HSpacing(1),
          TimeoutWidget.new(hiden_menu_widget),
          HSpacing(1),
          VBox(
            Left(Yast::Arch.s390 ? CWM::Empty.new("os_prober") : OSProberWidget.new),
            VSpacing(1),
            Left(hiden_menu_widget)
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
