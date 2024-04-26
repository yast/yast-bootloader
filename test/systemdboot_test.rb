# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/systemdboot"

describe Bootloader::SystemdBoot do
  subject do
    sub = described_class.new
    sub
  end

  let(:destdir) { File.expand_path("data/", __dir__) }
  let(:cmdline_content) { "splash=silent quiet security=apparmor mitigations=off" }

  before do
    allow(Yast::BootStorage).to receive(:available_swap_partitions).and_return([])
    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
    allow(Yast::Package).to receive(:Available).and_return(true)
  end

  describe "#read" do
    before do
      expect(Bootloader::Systeminfo).to receive(:secure_boot_active?).and_return(true)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
    end

    it "reads bootloader flags from sysconfig" do
      subject.read

      expect(subject.secure_boot).to eq true
    end

    it "reads entries from /etc/kernel/cmdline" do
      subject.read

      expect(subject.cpu_mitigations.to_human_string).to eq "Off"
      expect(subject.kernel_params.serialize).to eq cmdline_content
    end
  end

  describe "#write" do
    before do
      allow(subject).to receive(:secure_boot).and_return(false)
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
      subject.kernel_params.replace(cmdline_content)
      subject.menue_timeout = 10
    end

    it "installs the bootloader" do
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")
      allow_any_instance_of(CFA::SystemdBoot).to receive(:save)

      # install bootloader
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")

      subject.write
    end

    it "writes kernel cmdline" do
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")
      allow_any_instance_of(CFA::SystemdBoot).to receive(:save)

      subject.write
      # Checking written kernel parameters
      subject.read
      expect(subject.cpu_mitigations.to_human_string).to eq "Off"
      expect(subject.kernel_params.serialize).to eq cmdline_content
    end

    it "creates menue entries" do
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")
      allow_any_instance_of(CFA::SystemdBoot).to receive(:save)

      # create menue entries
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")

      subject.write
    end

    it "saves menue timeout" do
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")

      # Saving menue timeout
      expect_any_instance_of(CFA::SystemdBoot).to receive(:save)

      subject.write
    end
  end

  describe "#packages" do
    it "adds to list shim and mokutil on x86_64 with secure boot" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      subject.secure_boot = true

      expect(subject.packages).to include("shim")
    end
  end

  describe "#summary" do
    it "returns line with boot loader type specified" do
      expect(subject.summary).to include("Boot Loader Type: Systemd Boot")
    end

    it "returns line with secure boot option specified" do
      subject.secure_boot = false

      expect(subject.summary).to include(match(/Secure Boot: disabled/))
    end
  end

  describe "#merge" do
    it "overwrite secure boot, mitigations and menue timeout if specified in merged one" do
      other_cmdline = "splash=silent quiet mitigations=auto"
      other = described_class.new
      other.secure_boot = true
      other.menue_timeout = 12
      other.kernel_params.replace(other_cmdline)

      subject.secure_boot = false
      subject.menue_timeout = 10
      subject.kernel_params.replace(cmdline_content)

      subject.merge(other)

      expect(subject.secure_boot).to eq true
      expect(subject.menue_timeout).to eq 12
      expect(subject.cpu_mitigations.to_human_string).to eq "Auto"
      expect(subject.kernel_params.serialize).to eq "security=apparmor splash=silent quiet mitigations=auto"
    end
  end

  describe "#propose" do
    it "proposes timeout to product/role default" do
      allow(Yast::ProductFeatures).to receive(:GetIntegerFeature)
        .with("globals", "boot_timeout").and_return(2)
      subject.propose

      expect(subject.menue_timeout).to eq 2
    end

    it "proposes secure boot" do
      allow(Bootloader::Systeminfo).to receive(:secure_boot_supported?).and_return(true)
      subject.propose

      expect(subject.secure_boot).to eq true
    end

    it "proposes kernel cmdline" do
      expect(Yast::BootArch).to receive(:DefaultKernelParams).and_return(cmdline_content)

      subject.propose
      expect(subject.kernel_params.serialize).to eq cmdline_content
    end
  end
end
