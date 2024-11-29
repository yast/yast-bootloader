#! /usr/bin/env rspec
# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/generic_widgets"
require "cwm/rspec"

describe Bootloader::LoaderTypeWidget do
  before do
    allow(Bootloader::BootloaderFactory)
      .to receive(:current)
      .and_return(double("TestBL", name: "test", propose: nil))
  end

  include_examples "CWM::ComboBox"
end

describe Bootloader::PMBRWidget do
  before do
    Bootloader::BootloaderFactory.clear_cache
    Bootloader::BootloaderFactory.current_name = "grub2-bls"
  end

  it "is initialized to pmbr action" do
    Bootloader::BootloaderFactory.current.pmbr_action = :add
    expect(subject).to receive(:value=).with(:add)

    subject.init
  end

  it "stores pmbr action" do
    expect(subject).to receive(:value).and_return(:remove)
    subject.store

    expect(Bootloader::BootloaderFactory.current.pmbr_action).to eq :remove
  end

  it "offer set, remove and no action options" do
    expect(subject.items.size).to eq 3
  end
end
