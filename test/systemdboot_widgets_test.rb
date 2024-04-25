# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/systemdboot_widgets"
require "cwm/rspec"

def assign_systemd_bootloader
  Bootloader::BootloaderFactory.clear_cache
  Bootloader::BootloaderFactory.current_name = "systemd-boot"
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

describe Bootloader::SystemdBootWidget::TimeoutWidget do

  before do
    assign_systemd_bootloader
  end

  it_behaves_like "CWM::CustomWidget"

  it "has minimal value to 0 as unlimited" do
    expect(subject.minimum).to eq(0)
  end

  it "has maximum value to 600" do
    expect(subject.maximum).to eq 600
  end

  it "has own complex content" do
    expect(subject.contents).to be_a Yast::Term
  end

  context "storing content" do
    before do
      stub_widget_value(:cont_boot, false)
      stub_widget_value(:seconds, 15)
    end

    it "sets timeout to -1 for using menu-force" do
      subject.store

      expect(bootloader.menue_timeout).to eq(-1)
    end
  end
end

describe Bootloader::SystemdBootWidget::SecureBootWidget do
  before do
    assign_systemd_bootloader
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

describe Bootloader::Grub2Widget::SdCpuMitigationsWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"
  it_behaves_like "CWM::ComboBox"

  context "when none bootloader is selected" do
    before do
      assign_bootloader("none")
    end

    describe "#init" do
      it "disables widget" do
        expect(subject).to receive(:disable)

        subject.init
      end
    end

    describe "#store" do
      it "does nothing on disabled widget" do
        expect(subject).to receive(:enabled?).and_return(false)
        expect(subject).to_not receive(:value)

        subject.store
      end
    end
  end
end

describe Bootloader::Grub2Widget::SdKernelAppendWidget do
  before do
    assign_bootloader
  end

  it_behaves_like "labeled widget"

  it "is initialized to kernel command line option" do
    bootloader.kernel_params.replace("verbose showopts")
    expect(subject).to receive(:value=).with("verbose showopts")

    subject.init
  end

  it "stores text as kernel command line option" do
    expect(subject).to receive(:value).and_return("showopts quiet")
    subject.store

    expect(bootloader.kernel_params.serialize).to eq "showopts quiet"
  end
end

describe Bootloader::SystemdBootWidget::KernelTab do
  before do
    assign_systemd_bootloader
  end

  include_examples "CWM::Tab"
end

describe Bootloader::SystemdBootWidget::BootCodeTab do
  before do
    assign_systemd_bootloader
  end

  include_examples "CWM::Tab"
end

describe Bootloader::SystemdBootWidget::BootloaderTab do
  before do
    allow(Yast::Package).to receive(:Available).and_return(true)
    assign_systemd_bootloader
  end

  include_examples "CWM::Tab"
end
