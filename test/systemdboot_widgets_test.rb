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

  it_behaves_like "labeled widget"

  it "has minimal value to -1 as unlimited" do
    expect(subject.minimum).to eq(-1)
  end

  it "has maximum value to 600" do
    expect(subject.maximum).to eq 600
  end

  it "is initialized to timeout value if defined" do
    bootloader.menue_timeout = "10"
    expect(subject).to receive(:value=).with(10)

    subject.init
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
