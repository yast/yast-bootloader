#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/sections"

describe Bootloader::Sections do
  subject do
    grub_cfg = double("CFA::Grub2::GrubCfg", sections: ["linux", "windows"])
    Bootloader::Sections.new(grub_cfg)
  end

  describe "#all" do
    it "returns list of all available sections" do
      expect(subject.all).to eq(["linux", "windows"])
    end
  end

  describe "#default" do
    it "gets name of default section stored in grub2" do
      expect(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/grub2-editenv", "list", stdout: :capture)
        .and_return("saved_entry=windows\nbla_bla=no\n")

      expect(subject.default).to eq "windows"
    end

    it "gets first section if nothing stored in grub2" do
      expect(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/grub2-editenv", "list", stdout: :capture)
        .and_return("\n")

      expect(subject.default).to eq "linux"
    end

    it "gets value written by #default=" do
      subject.default = "windows"

      expect(subject.default).to eq "windows"
    end
  end

  describe "#default=" do
    it "sets new value for default" do
      subject.default = "windows"

      expect(subject.default).to eq "windows"
    end
  end

  describe "#write" do
    it "writes default value" do
      subject.default = "linux"

      expect(Yast::Execute).to receive(:on_target)
        .with("/usr/sbin/grub2-set-default", "linux")

      subject.write
    end
  end
end
