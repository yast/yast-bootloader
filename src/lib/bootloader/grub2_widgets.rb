require "yast"

require "bootloader/generic_widgets"
require "bootloader/device_map_dialog"

Yast.import "BootStorage"
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
      _("<p><b>Timeout in Seconds</b><br>\n" \
        "Specifies the time the bootloader will wait until the default kernel is loaded.</p>\n"
       )
    end

    def init
      if grub_default.hidden_timeout && grub_default.hidden_timeout.to_i > 0
        self.value = grub_default.hidden_timeout
      else
        self.value = grub_default.timeout
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
        "<p><b>Set active Flag in Partition Table for Boot Partition</b><br>\n" \
          "To activate the partition which contains the boot loader. The generic MBR code will then\n" \
          "boot the active partition. Older BIOSes require one partition to be active even\n" \
          "if the boot loader is installed in the MBR.</p>"
      )
    end

    def init
      self.value = stage1.model.activate?
    end

    def store
      stage1.model.activate = checked?
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
      self.value = stage1.model.generic_mbr?
    end

    def store
      stage1.model.generic_mbr = checked?
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
      self.value = grub_default.kernel_params.serialize
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
      _("Protective MBR flag")
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
      _("Tick to enable UEFI Secure Boot\n")
    end

    def init
      self.value = grub2.secure_boot
    end

    def store
      grub2.secure_boot = value
    end
  end

  # Represents grub password protection widget
  class GrubPasswordWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    MASKED_PASSWORD = "**********"

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
      if !usepass
        password.used = false
        return
      end

      password.used = true

      value = Yast::UI.QueryWidget(Id(:pw1), :Value)
      # special value as we do not know password, so it mean user do not change it
      password.password = value if value != MASKED_PASSWORD

      value = Yast::UI.QueryWidget(Id(:unrestricted_pw), :Value)
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

  # Represents graphical and serial console for bootloader
  class ConsoleWidget < CWM::CustomWidget
    include Grub2Widget

    def initialize
      textdomain "bootloader"
    end

    def contents
      # TODO: simplify a bit content or split it
      VBox(
        graphical_console_frame,
        serial_console_frame
      )
    end

    def init
      enable = grub_default.terminal == :serial
      Yast::UI.ChangeWidget(Id(:console_frame), :Value, enable)
      args = grub_default.serial_console || ""
      Yast::UI.ChangeWidget(Id(:console_args), :Value, args)

      enable = grub_default.terminal == :gfxterm
      Yast::UI.ChangeWidget(Id(:gfxterm_frame), :Value, enable)

      Yast::UI.ChangeWidget(Id(:gfxmode), :Items, vga_modes_items)
      mode = grub_default.gfxmode

      # there's mode specified, use it
      Yast::UI.ChangeWidget(Id(:gfxmode), :Value, mode) if mode && mode != ""

      Yast::UI.ChangeWidget(Id(:theme), :Value, grub_default.theme)
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

  private

    def graphical_console_frame
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
      )
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
        "<p> By pressing <b>Set as Default</b> you mark the selected section as\n" \
        "the default. When booting, the boot loader will provide a boot menu and\n" \
        "wait for the user to select a kernel or OS to boot. If no\n" \
        "key is pressed before the timeout, the default kernel or OS will\n" \
        "boot. The order of the sections in the boot loader menu can be changed\n" \
        "using the <b>Up</b> and <b>Down</b> buttons.</p>\n"
      )
    end

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

  # Represents stage1 location for bootloader
  class LoaderLocationWidget < CWM::CustomWidget
    include Grub2Widget

    def contents
      textdomain "bootloader"

      checkboxes = []
      locations = stage1.available_locations
      if locations[:boot]
        checkboxes << Left(CheckBox(Id(:boot), _("Boo&t from Boot Partition")))
      end
      if locations[:root]
        checkboxes << Left(CheckBox(Id(:root), _("Boo&t from Root Partition")))
      end
      if locations[:mbr]
        checkboxes << Left(CheckBox(Id(:mbr), _("Boot from &Master Boot Record")))
      end
      if locations[:extended]
        checkboxes << Left(CheckBox(Id(:extended), _("Boot from &Extended Partition")))
      end
      checkboxes << Left(CheckBox(Id(:custom), Opt(:notify), _("C&ustom Boot Partition")))
      checkboxes << Left(InputField(Id(:custom_list), Opt(:hstretch), ""))

      VBox(
        VSpacing(1),
        Frame(
          _("Boot Loader Location"),
          HBox(
            HSpacing(1),
            VBox(*checkboxes),
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
      locations = stage1.available_locations
      if locations[:boot]
        Yast::UI.ChangeWidget(Id(:boot), :Value, stage1.boot_partition?)
      end
      if locations[:root]
        Yast::UI.ChangeWidget(Id(:root), :Value, stage1.root_partition?)
      end
      if locations[:extended]
        Yast::UI.ChangeWidget(Id(:extended), :Value, stage1.extended_partition?)
      end
      Yast::UI.ChangeWidget(Id(:mbr), :Value, stage1.mbr?) if locations[:mbr]
      custom_devices = stage1.custom_devices
      if custom_devices.empty?
        Yast::UI.ChangeWidget(:custom, :Value, false)
        Yast::UI.ChangeWidget(:custom_list, :Enabled, false)
      else
        Yast::UI.ChangeWidget(:custom, :Value, true)
        Yast::UI.ChangeWidget(:custom_list, :Enabled, true)
        Yast::UI.ChangeWidget(:custom_list, :Value, custom_devices.join(","))
      end
    end

    def store
      locations = stage1.available_locations
      stage1.clear_devices
      locations.each_pair do |id, dev|
        stage1.add_udev_device(dev) if Yast::UI.QueryWidget(Id(id), :Value)
      end

      return unless Yast::UI.QueryWidget(:custom, :Value)

      devs = Yast::UI.QueryWidget(:custom_list, :Value)
      devs.split(",").each do |dev|
        stage1.add_udev_device(dev.strip)
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
  end

  # Represents button that open Device Map edit dialog
  class DeviceMapWidget < ::CWM::PushButton
    def label
      textdomain "bootloader"

      _("Edit Disk Boot Order")
    end

    def help
      textdomain "bootloader"

      _(
        "<p><big><b>Disks Order</b></big><br>\n" \
          "To specify the order of the disks according to the order in BIOS, use\n" \
          "the <b>Up</b> and <b>Down</b> buttons to reorder the disks.\n" \
          "To add a disk, push <b>Add</b>.\n" \
          "To remove a disk, push <b>Remove</b>.</p>"
      )
    end

    def handle
      DeviceMapDialog.run

      nil
    end
  end

  # represents Tab with kernel related configuration
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

  # Represent tab with options related to stage1 location and bootloader type
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
      widgets = []

      widgets << indented_widget(LoaderLocationWidget.new) if loader_location_widget?

      if generic_mbr_widget?
        widgets << indented_widget(ActivateWidget.new)
        widgets << indented_widget(GenericMBRWidget.new)
      end

      widgets << indented_widget(SecureBootWidget.new) if secure_boot_widget?

      widgets << indented_widget(PMBRWidget.new) if pmbr_widget?

      widgets << indented_widget(DeviceMapWidget.new) if device_map_button?

      VBox(
        LoaderTypeWidget.new,
        *widgets,
        VStretch()
      )
    end

  private

    def indented_widget(widget)
      MarginBox(1, 0.5, Left(widget))
    end

    def loader_location_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.ppc) && grub2.name == "grub2"
    end

    def generic_mbr_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386) && grub2.name != "grub2-efi"
    end

    def secure_boot_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386) && grub2.name == "grub2-efi"
    end

    def pmbr_widget?
      (Yast::Arch.x86_64 || Yast::Arch.i386) &&
        (Yast::BootStorage.gpt_boot_disk? || grub2.name == "grub2-efi")
    end

    def device_map_button?
      (Yast::Arch.x86_64 || Yast::Arch.i386 || Yast::Arch.ppc) && grub2.name != "grub2-efi"
    end
  end

  # Represents bootloader specific options like its timeout, default section or password protection
  class BootloaderTab < CWM::Tab
    def label
      textdomain "bootloader"

      _("Bootloader Options")
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
