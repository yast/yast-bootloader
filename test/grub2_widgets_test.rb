require_relative "test_helper"

require "bootloader/grub2_widgets"

def assign_bootloader(name = "grub2")
  Bootloader::BootloaderFactory.clear_cache
  Bootloader::BootloaderFactory.current_name = name
end

def bootloader
  Bootloader::BootloaderFactory.current
end

# needed for custom widgets
def stub_widget_value(id, value)
  allow(Yast::UI).to receive(:QueryWidget).with(Id(id), :Value).and_return(value)
end

shared_examples "labeled widget" do
  it "has label" do
    expect(subject.label).to_not be_empty
  end

  it "has help" do
    expect(subject.help).to_not be_empty
  end
end

describe Bootloader::TimeoutWidget do
  subject(:widget) do
    described_class.new(hidden_menu_widget)
  end

  let(:hidden_menu_widget) { double(checked?: false) }

  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "has minimal value to -1 as unlimited" do
    expect(widget.minimum).to eq(-1)
  end

  it "has maximum value to 600" do
    expect(widget.maximum).to eq 600
  end

  it "is initialized to hidden timeout value if defined" do
    bootloader.grub_default.hidden_timeout = "10"
    expect(subject).to receive(:value=).with("10")

    subject.init
  end

  it "is initialized to timeout value otherwise" do
    bootloader.grub_default.hidden_timeout = ""
    bootloader.grub_default.timeout = "10"
    expect(subject).to receive(:value=).with("10")

    subject.init
  end

  context "hidden menu widget checked" do
    let(:hidden_menu_widget) { double(checked?: true) }

    it "stores its value to hidden_timeout configuration" do
      expect(subject).to receive(:value).and_return("20")
      subject.store

      expect(bootloader.grub_default.hidden_timeout).to eq "20"
    end

    it "stores \"0\" to timeout configuration" do
      expect(subject).to receive(:value).and_return("20")
      subject.store

      expect(bootloader.grub_default.timeout).to eq "0"
    end
  end

  context "hidden menu widget unchecked" do
    let(:hidden_menu_widget) { double(checked?: false) }

    it "stores its value to timeout configuration" do
      expect(subject).to receive(:value).and_return("20")
      subject.store

      expect(bootloader.grub_default.timeout).to eq "20"
    end

    it "stores \"0\" to hidden_timeout configuration" do
      expect(subject).to receive(:value).and_return("20")
      subject.store

      expect(bootloader.grub_default.hidden_timeout).to eq "0"
    end
  end
end

describe Bootloader::ActivateWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized to activate flag" do
    bootloader.stage1.model.activate = true
    expect(subject).to receive(:value=).with(true)

    subject.init
  end

  it "stores activate flag" do
    expect(subject).to receive(:value).and_return(true)
    subject.store

    expect(bootloader.stage1.model.activate?).to eq true
  end
end

describe Bootloader::GenericMBRWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized to generic MBR flag" do
    bootloader.stage1.model.generic_mbr = true
    expect(subject).to receive(:value=).with(true)

    subject.init
  end

  it "stores generic MBR flag" do
    expect(subject).to receive(:value).and_return(true)
    subject.store

    expect(bootloader.stage1.model.generic_mbr?).to eq true
  end
end

describe Bootloader::HiddenMenuWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized as checked if hidden timeout value is bigger then zero" do
    bootloader.grub_default.hidden_timeout = "5"
    expect(subject).to receive(:value=).with(true)

    subject.init
  end
end

describe Bootloader::OSProberWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized to os prober flag" do
    bootloader.grub_default.os_prober.enable
    expect(subject).to receive(:value=).with(true)

    subject.init
  end

  it "stores os prober flag" do
    expect(subject).to receive(:value).and_return(true)
    subject.store

    expect(bootloader.grub_default.os_prober).to be_enabled
  end
end

describe Bootloader::KernelAppendWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized to kernel command line option" do
    bootloader.grub_default.kernel_params.replace("verbose showopts")
    expect(subject).to receive(:value=).with("verbose showopts")

    subject.init
  end

  it "stores text as kernel command line option" do
    expect(subject).to receive(:value).and_return("showopts quiet")
    subject.store

    expect(bootloader.grub_default.kernel_params.serialize).to eq "showopts quiet"
  end
end

describe Bootloader::PMBRWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized to pmbr action" do
    bootloader.pmbr_action = :add
    expect(subject).to receive(:value=).with(:add)

    subject.init
  end

  it "stores pmbr action" do
    expect(subject).to receive(:value).and_return(:remove)
    subject.store

    expect(bootloader.pmbr_action).to eq :remove
  end

  it "offer set, remove and no action options" do
    expect(subject.items.size).to eq 3
  end
end

describe Bootloader::SecureBootWidget do
  before do
    assign_bootloader("grub2-efi")
  end

  it_behaves_like "labeled widget"

  it "is initialized to secure boot flag" do
    bootloader.secure_boot = true
    expect(subject).to receive(:value=).with(true)

    subject.init
  end

  it "stores secure boot flag flag" do
    expect(subject).to receive(:value).and_return(true)
    subject.store

    expect(bootloader.secure_boot).to eq true
  end
end

describe Bootloader::GrubPasswordWidget do
  before do
    assign_bootloader
  end

  it "has help" do
    expect(subject.help).to_not be_empty
  end

  it "has own complex content" do
    expect(subject.contents).to be_a Yast::Term
  end

  context "validation" do
    before do
      stub_widget_value(:use_pas, true)
    end

    it "is valid if password is not used" do
      stub_widget_value(:use_pas, false)

      expect(subject.validate).to eq true
    end

    it "reports error if password is empty" do
      stub_widget_value(:pw1, "")

      expect(Yast::Report).to receive(:Error)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))

      expect(subject.validate).to eq false
    end

    it "reports error if passwords do not match" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "b")

      expect(Yast::Report).to receive(:Error)
      expect(Yast::UI).to receive(:SetFocus).with(Id(:pw1))

      expect(subject.validate).to eq false
    end

    it "is valid if both password field are same and non-empty" do
      stub_widget_value(:pw1, "a")
      stub_widget_value(:pw2, "a")

      expect(subject.validate).to eq true
    end
  end

  context "initialization" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget)
    end

    context "password is configured" do
      before do
        bootloader.password.used = true
      end

      it "checks use password checkbox" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:use_pas), :Value, true)

        subject.init
      end

      it "enables password1 field" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw1), :Enabled, true)

        subject.init
      end

      it "enables password2 field" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw2), :Enabled, true)

        subject.init
      end

      it "enables unrestricted password checkbox" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:unrestricted_pw), :Enabled, true)

        subject.init
      end
    end

    context "password is not configured" do
      before do
        bootloader.password.used = false
      end

      it "unchecks use password checkbox" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:use_pas), :Value, false)

        subject.init
      end

      it "disables password1 field" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw1), :Enabled, false)

        subject.init
      end

      it "disables password2 field" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw2), :Enabled, false)

        subject.init
      end

      it "disables unrestricted password checkbox" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:unrestricted_pw), :Enabled, false)

        subject.init
      end
    end

    it "sets unresticted boot flag to its checkbox" do
      bootloader.password.unrestricted = false
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:unrestricted_pw), :Value, false)

      subject.init
    end
  end

  context "event handling" do
    it "does nothing unless use password check is changed" do
      expect(Yast::UI).to_not receive(:ChangeWidget)

      subject.handle("ID" => :pw1)
    end

    it "enables passwords and unresticted password widgets if checked" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:use_pas), :Value).and_return(true)

      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:unrestricted_pw), :Enabled, true)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw1), :Enabled, true)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw2), :Enabled, true)

      subject.handle("ID" => :use_pas)
    end

    it "disables passwords and unresticted password widgets if unchecked" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:use_pas), :Value).and_return(false)

      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:unrestricted_pw), :Enabled, false)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw1), :Enabled, false)
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:pw2), :Enabled, false)

      subject.handle("ID" => :use_pas)
    end
  end

  context "storing content" do
    context "use password checkbox unchecked" do
      it "sets that password protection is not used" do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:use_pas), :Value).and_return(false)

        subject.store

        expect(bootloader.password.used).to eq false
      end
    end

    context "use password checkbox checked" do
      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:use_pas), :Value).and_return(true)
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:pw1), :Value).and_return("pwd")
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:unrestricted_pw), :Value).and_return(true)
        # mock out setting password as it require external grub2 utility for pwd encryption
        allow(bootloader.password).to receive(:password=)
      end

      it "sets that password protection is used" do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:use_pas), :Value).and_return(true)

        subject.store

        expect(bootloader.password.used).to eq true
      end

      it "sets password unrestricted value" do
        expect(Yast::UI).to receive(:QueryWidget).with(Id(:unrestricted_pw), :Value).and_return(false)

        subject.store

        expect(bootloader.password.unrestricted?).to eq false
      end

      it "sets password value if its value changed" do
        expect(Yast::UI).to receive(:QueryWidget).with(Id(:pw1), :Value).and_return("pwd")

        # mock setting it as it internally hash its value, so hard to verify it
        expect(bootloader.password).to receive(:password=).with("pwd")
        subject.store
      end
    end
  end
end

describe Bootloader::ConsoleWidget do
  before do
    assign_bootloader
  end

  it "has own complex content" do
    expect(subject.contents).to be_a Yast::Term
  end

  context "initialization" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget)
    end

    it "checks serial console checkbox if grub use it" do
      bootloader.grub_default.terminal = :serial

      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:console_frame), :Value, true)

      subject.init
    end

    it "fills serial console parameters" do
      bootloader.grub_default.serial_console = "serial --unit=1"

      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:console_args), :Value, "serial --unit=1")

      subject.init
    end

    it "checks graphical console checkbox if grub use it" do
      bootloader.grub_default.terminal = :gfxterm

      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:gfxterm_frame), :Value, true)

      subject.init
    end

    it "fills list of available graphical resolutions and select current one" do
      bootloader.grub_default.gfxmode = "0x380"
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:gfxmode), :Value, "0x380")
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:gfxmode), :Items, anything)

      subject.init
    end

    it "sets current grub theme" do
      bootloader.grub_default.theme = "/usr/share/grub2/theme"

      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:theme), :Value, "/usr/share/grub2/theme")

      subject.init
    end
  end

  context "event handling" do
    it "does nothing unless browse button pressed" do
      expect(Yast::UI).to_not receive(:ChangeWidget)

      subject.handle("ID" => :theme)
    end

    it "open file selecter after button pressed and store its result to theme widget" do
      expect(Yast::UI).to receive(:AskForExistingFile).and_return("/boot/grub2/cool_theme")
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:theme), :Value, "/boot/grub2/cool_theme")

      subject.handle("ID" => :browsegfx)
    end

    it "does not update theme field if file selector is canceled" do
      expect(Yast::UI).to receive(:AskForExistingFile).and_return(nil)
      expect(Yast::UI).to_not receive(:ChangeWidget)

      subject.handle("ID" => :browsegfx)
    end
  end

  context "storing content" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:console_frame), :Value).and_return(false)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:gfxterm_frame), :Value).and_return(false)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:gfxmode), :Value).and_return("")
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:theme), :Value).and_return("")
    end

    it "sets terminal to serial using serial parameters if serial console selected" do
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:console_frame), :Value).and_return(true)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:console_args), :Value)
        .and_return("serial --unit=1 --speed=9600 --parity=even")

      subject.store

      expect(bootloader.grub_default.terminal).to eq :serial
      expect(bootloader.grub_default.serial_console).to eq "serial --unit=1 --speed=9600 --parity=even"
      # it also sets console args to kernel params, but it will be duplication of serial console test
    end

    it "sets terminal to graphical one if graphical console is checked" do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:gfxterm_frame), :Value).and_return(true)

      subject.store

      expect(bootloader.grub_default.terminal).to eq :gfxterm
    end

    it "sets serial terminal if both graphical and serial is selected" do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:console_frame), :Value).and_return(true)
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:gfxterm_frame), :Value).and_return(true)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:console_args), :Value)
        .and_return("serial --unit=1 --speed=9600 --parity=even")

      subject.store

      expect(bootloader.grub_default.terminal).to eq :serial
    end

    it "sets console terminal if neither graphical nor serial console selected" do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:console_frame), :Value).and_return(false)
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:gfxterm_frame), :Value).and_return(false)

      subject.store

      expect(bootloader.grub_default.terminal).to eq :console
    end

    it "stores theme value" do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:theme), :Value).and_return("/boot/grub2/cool_theme")

      subject.store

      expect(bootloader.grub_default.theme).to eq "/boot/grub2/cool_theme"
    end

    it "stores graphical mode" do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:gfxmode), :Value).and_return("0x860")

      subject.store

      expect(bootloader.grub_default.gfxmode).to eq "0x860"
    end
  end
end

describe Bootloader::DefaultSectionWidget do
  before do
    grub_cfg = double(sections: ["openSUSE", "windows"])
    assign_bootloader
    sections = Bootloader::Sections.new(grub_cfg)
    # fake section list
    allow(bootloader).to receive(:sections).and_return(sections)
  end

  it_behaves_like "labeled widget"

  it "is initialized to current default section" do
    bootloader.sections.default = "openSUSE"
    expect(subject).to receive(:value=).with("openSUSE")

    subject.init
  end

  it "stores default section" do
    expect(subject).to receive(:value).and_return("openSUSE")
    subject.store

    expect(bootloader.sections.default).to eq "openSUSE"
  end

  it "enlists all available sections" do
    expect(subject.items).to eq([
      ["openSUSE", "openSUSE"],
      ["windows", "windows"]
    ])
  end
end

describe Bootloader::DeviceMapWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "opens device map dialog after pressing" do
    expect(Bootloader::DeviceMapDialog).to receive(:run)

    subject.handle
  end
end
