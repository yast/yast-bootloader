# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/bls_widgets"
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

describe Bootloader::BlsWidget::TimeoutWidget do

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

      expect(bootloader.timeout).to eq(-1)
    end
  end
end
