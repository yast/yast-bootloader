#! /usr/bin/env rspec --format doc
# frozen_string_literal: true

require_relative "./test_helper"

require "bootloader/bls_sections"
require "cfa/memory_file"

describe Bootloader::BlsSections do

  before do
    allow(Yast::Misc).to receive(:CustomSysconfigRead)
      .with("ID_LIKE", "openSUSE", "/etc/os-release")
      .and_return("openSUSE")
  end

  describe "#read" do
    before do
      allow(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/bootctl", "--json=short", "list", stdout: :capture)
        .and_return("[{\"title\" : \"openSUSE Tumbleweed\", \"isDefault\" : true }," \
                    "{\"title\" : \"Snapper: *openSUSE Tumbleweed 20241107\", \"isDefault\" : false}]")
      allow(Yast::Misc).to receive(:CustomSysconfigRead)
        .with("default", "", "/boot/efi/EFI/openSUSE/grubenv")
        .and_return("openSUSE Tumbleweed")
      subject.read
    end

    it "returns list of all available sections" do
      expect(subject.all).to eq(["openSUSE Tumbleweed", "Snapper: *openSUSE Tumbleweed 20241107"])
    end

    it "reads default menu entry" do
      expect(subject.default).to eq("openSUSE Tumbleweed")
    end
  end

  describe "#default=" do
    before do
      allow(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/bootctl", "--json=short", "list", stdout: :capture)
        .and_return("[{\"title\" : \"openSUSE Tumbleweed\", \"isDefault\" : true }," \
                    "{\"title\" : \"Snapper: *openSUSE Tumbleweed 20241107\", \"isDefault\" : false}]")
      allow(Yast::Misc).to receive(:CustomSysconfigRead)
        .with("default", "", "/boot/efi/EFI/openSUSE/grubenv")
        .and_return("openSUSE Tumbleweed")
      subject.read
    end
    it "sets new value for default" do
      subject.default = "Snapper: *openSUSE Tumbleweed 20241107"
      expect(subject.default).to eq "Snapper: *openSUSE Tumbleweed 20241107"
    end

    it "sets default to empty if section do not exists" do
      subject.default = "non-exist"
      expect(subject.default).to eq ""
    end
  end

  describe "#write" do
    it "writes default value if set" do
      subject.default = "Snapper: *openSUSE Tumbleweed 20241107"
      expect(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/sdbootutil", "set-default", subject.default)
      subject.write
    end

    it "does not write default value if not set" do
      subject.default = ""
      expect(Yast::Execute).to_not receive(:on_target)
        .with("/usr/bin/sdbootutil", "set-default", subject.default)
      subject.write
    end

  end
end
