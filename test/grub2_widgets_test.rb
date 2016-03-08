require_relative "test_helper"

require "bootloader/grub2_widgets"

def assign_bootloader(name = "grub2")
  Bootloader::BootloaderFactory.clear_cache
  Bootloader::BootloaderFactory.current_name = name
end

def bootloader
  Bootloader::BootloaderFactory.current
end

shared_examples "described_widget" do
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

  it_behaves_like "described_widget"

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

  it_behaves_like "described_widget"

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

  it_behaves_like "described_widget"

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

  it_behaves_like "described_widget"

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

  it_behaves_like "described_widget"

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
