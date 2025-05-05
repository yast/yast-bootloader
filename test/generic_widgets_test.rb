#! /usr/bin/env rspec
# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/generic_widgets"
require "cwm/rspec"

def assign_bootloader(name = "grub2")
  Bootloader::BootloaderFactory.clear_cache
  Bootloader::BootloaderFactory.current_name = name
end

def bootloader
  Bootloader::BootloaderFactory.current
end

shared_examples "labeled widget" do
  it "has label" do
    expect(subject.label).to_not be_empty
  end

  it "has help" do
    expect(subject.help).to_not be_empty
  end
end

describe Bootloader::LoaderTypeWidget do
  before do
    allow(Bootloader::BootloaderFactory)
      .to receive(:current)
      .and_return(double("TestBL", name: "test", propose: nil))
  end

  include_examples "CWM::ComboBox"
end

describe Bootloader::Grub2Widget::SecureBootWidget do
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

describe Bootloader::PMBRWidget do
  before do
    assign_bootloader("grub2-bls")
  end

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
