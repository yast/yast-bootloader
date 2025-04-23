# frozen_string_literal: true

require_relative "test_helper"
require "bootloader/bls"
require "bootloader/grub2bls"

describe Bootloader::Grub2Bls do
  subject do
    sub = described_class.new
    sub
  end

  let(:destdir) { File.expand_path("data/", __dir__) }
  let(:cmdline_content) { "splash=silent quiet security=apparmor mitigations=off" }

  before do
    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
    allow(Bootloader::Bls).to receive(:default_menu)
      .and_return(subject.sections.default)
  end

  describe "#read" do
    before do
      allow(Bootloader::Bls).to receive(:menu_timeout)
        .and_return(10)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
    end

    it "reads menu timeout" do
      subject.read

      expect(subject.grub_default.timeout).to eq 10
    end

    it "reads entries from /etc/kernel/cmdline" do
      subject.read

      expect(subject.cpu_mitigations.to_human_string).to eq "Off"
      expect(subject.grub_default.kernel_params.serialize).to end_with cmdline_content
    end
  end

  describe "#write" do
    before do
      allow(Yast::Stage).to receive(:initial).and_return(false)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
      subject.grub_default.kernel_params.replace(cmdline_content)
      subject.grub_default.timeout = 10
    end

    it "setups protective mbr to real disks containing /boot/efi" do
      subject.pmbr_action = :add
      allow(Bootloader::Bls).to receive(:default_menu)
        .and_return(subject.sections.default)
      allow(Bootloader::Bls).to receive(:write_default_menu)
        .with(subject.sections.default)
      allow(Bootloader::Bls).to receive(:menu_timeout)
        .and_return(subject.grub_default.timeout)
      allow(Bootloader::Bls).to receive(:write_menu_timeout)
        .with(subject.grub_default.timeout)
      allow(Bootloader::Bls).to receive(:create_menu_entries)
      allow(Bootloader::Bls).to receive(:install_bootloader)
      allow(Yast::BootStorage).to receive(:gpt_boot_disk?).and_return(true)

      expect(Yast::Execute).to receive(:locally)
        .with("/usr/sbin/parted", "-s", "/dev/sda", "disk_set", "pmbr_boot", "on")

      subject.write
    end

    it "installs the bootloader" do
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Bootloader::Bls).to receive(:write_default_menu)
        .with(subject.sections.default)
      allow(Bootloader::Bls).to receive(:write_menu_timeout)
        .with(subject.grub_default.timeout)

      # install bootloader
      expect(Bootloader::Bls).to receive(:install_bootloader)
      expect(Bootloader::Bls).to receive(:set_authentication)

      # create menu entries
      expect(Bootloader::Bls).to receive(:create_menu_entries)

      subject.write
    end

    it "writes kernel cmdline" do
      allow(Bootloader::Bls).to receive(:default_menu)
        .and_return(subject.sections.default)
      allow(Bootloader::Bls).to receive(:write_default_menu)
        .with(subject.sections.default)
      allow(Bootloader::Bls).to receive(:menu_timeout)
        .and_return(subject.grub_default.timeout)
      allow(Bootloader::Bls).to receive(:write_menu_timeout)
        .with(subject.grub_default.timeout)
      allow(Bootloader::Bls).to receive(:create_menu_entries)
      allow(Bootloader::Bls).to receive(:install_bootloader)

      subject.write
      # Checking written kernel parameters
      subject.read
      expect(subject.cpu_mitigations.to_human_string).to eq "Off"
      expect(subject.grub_default.kernel_params.serialize).to end_with cmdline_content
    end

    it "saves menu timeout" do
      allow(Bootloader::Bls).to receive(:create_menu_entries)
      allow(Bootloader::Bls).to receive(:install_bootloader)
      allow(Bootloader::Bls).to receive(:write_default_menu)
        .with(subject.sections.default)
      # Saving menu timeout
      expect(Bootloader::Bls).to receive(:write_menu_timeout)
        .with(subject.grub_default.timeout)
      subject.write
    end
  end

  describe "#packages" do
    it "adds grub2-<arch>-efi-bls and sdbootutil packages" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      allow(Yast::Package).to receive(:Available).with("os-prober").and_return(true)
      expect(subject.packages).to include("grub2-" + Yast::Arch.architecture + "-efi-bls")
      expect(subject.packages).to include("sdbootutil")
    end
  end

  describe "#summary" do
    it "returns line with boot loader type specified" do
      expect(subject.summary).to include("Boot Loader Type: GRUB2 BLS")
    end

  end

  describe "#merge" do
    it "overwrite  mitigations and menu timeout if specified in merged one" do
      other_cmdline = "splash=silent quiet mitigations=auto"
      other = described_class.new
      other.grub_default.timeout = 12
      other.grub_default.kernel_params.replace(other_cmdline)

      subject.grub_default.timeout = 10
      subject.grub_default.kernel_params.replace(cmdline_content)

      subject.merge(other)

      expect(subject.grub_default.timeout).to eq 12
      expect(subject.cpu_mitigations.to_human_string).to eq "Auto"
      expect(subject.grub_default.kernel_params.serialize).to include "security=apparmor splash=silent quiet mitigations=auto"
    end
  end

  describe "#propose" do
    before do
      allow(Yast::BootStorage).to receive(:available_swap_partitions).and_return({})
    end

    it "proposes timeout to product/role default" do
      allow(Yast::ProductFeatures).to receive(:GetIntegerFeature)
        .with("globals", "boot_timeout").and_return(2)
      subject.propose

      expect(subject.grub_default.timeout).to eq 2
    end

    it "proposes kernel cmdline" do
      expect(Yast::BootArch).to receive(:DefaultKernelParams).and_return(cmdline_content)

      subject.propose
      expect(subject.grub_default.kernel_params.serialize).to end_with cmdline_content
    end
  end
end
