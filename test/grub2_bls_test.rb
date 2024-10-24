# frozen_string_literal: true

require_relative "test_helper"

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
  end

  describe "#read" do
    before do
      allow(Yast::Misc).to receive(:CustomSysconfigRead)
        .with("ID_LIKE", "openSUSE", "/etc/os-release")
        .and_return("openSUSE")
      allow(Yast::Misc).to receive(:CustomSysconfigRead)
        .with("timeout", "", "/boot/efi/EFI/openSUSE/grubenv")
        .and_return("10")
      allow(Yast::Misc).to receive(:CustomSysconfigRead)
        .with("default", "", "/boot/efi/EFI/openSUSE/grubenv")
        .and_return("")
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
    end

    it "reads menu timeout" do
      subject.read

      expect(subject.grub_default.timeout).to eq "10"
    end

    it "reads entries from /etc/kernel/cmdline" do
      subject.read

      expect(subject.cpu_mitigations.to_human_string).to eq "Off"
      expect(subject.grub_default.kernel_params.serialize).to eq cmdline_content
    end
  end

  describe "#write" do
    before do
      allow(Yast::Stage).to receive(:initial).and_return(false)
      allow(Yast::Installation).to receive(:destdir).and_return(destdir)
      subject.grub_default.kernel_params.replace(cmdline_content)
      subject.grub_default.timeout = 10
    end

    it "installs the bootloader" do
      allow(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/sdbootutil", "set-timeout",
          subject.grub_default.timeout,
          allowed_exitstatus: [0, 1])
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "set-default", subject.sections.default)

      # install bootloader
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")

      # create menu entries
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")

      subject.write
    end

    it "writes kernel cmdline" do
      allow(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/sdbootutil", "set-timeout",
          subject.grub_default.timeout,
          allowed_exitstatus: [0, 1])
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "set-default", subject.sections.default)
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")

      subject.write
      # Checking written kernel parameters
      subject.read
      expect(subject.cpu_mitigations.to_human_string).to eq "Off"
      expect(subject.grub_default.kernel_params.serialize).to include cmdline_content
    end

    it "saves menu timeout" do
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "set-default", subject.sections.default)
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "install")
      allow(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/sdbootutil", "--verbose", "add-all-kernels")

      # Saving menu timeout
      expect(Yast::Execute).to receive(:on_target)
        .with("/usr/bin/sdbootutil", "set-timeout",
          subject.grub_default.timeout,
          allowed_exitstatus: [0, 1])
      subject.write
    end
  end

  describe "#packages" do
    it "adds grub2* and sdbootutil packages" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      allow(Yast::Package).to receive(:Available).with("os-prober").and_return(true)
      expect(subject.packages).to include("grub2-" + Yast::Arch.architecture + "-efi-bls")
      expect(subject.packages).to include("sdbootutil")
      expect(subject.packages).to include("grub2")
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
      expect(subject.grub_default.kernel_params.serialize).to eq cmdline_content
    end
  end
end
