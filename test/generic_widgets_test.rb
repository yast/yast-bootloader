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

describe Bootloader::DefaultSectionWidget do
  before do
    sections = [
      { title: "openSUSE", path: "openSUSE" },
      { title: "windows", path: "windows" }
    ]
    grub_cfg = double(boot_entries: sections)
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
    sections = [["openSUSE", "openSUSE"], ["windows", "windows"]]

    expect(subject.items).to eq(sections)
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
