require_relative "test_helper"

require "bootloader/bootloader_base"

describe Bootloader::BootloaderBase do
  describe "#write" do
    before do
      allow(Bootloader::Sysconfig).to receive(:new).and_return(double(write: nil))
      allow(Yast::PackageSystem).to receive(:InstallAll)

      subject.define_singleton_method(:name) { "funny_bootloader" }
    end

    it "writes to sysconfig name of its child" do
      sysconfig = double(Bootloader::Sysconfig, write: nil)
      expect(Bootloader::Sysconfig).to receive(:new)
        .with(bootloader: "funny_bootloader")
        .and_return(sysconfig)

      subject.write
    end

    context "Mode.normal is set" do
      it "install packages required by bootloader" do
        expect(Yast::PackageSystem).to receive(:InstallAll).with(["kexec-tools"])

        subject.write
      end
    end
  end

  describe "#read" do
    it "detects disks in system" do
      expect(Yast::BootStorage).to receive(:detect_disks)

      subject.read
    end

    it "sets read flag" do
      expect(subject.read?).to eq false

      subject.read

      expect(subject.read?).to eq true
    end
  end

  describe "#propose" do
    it "detects disk configuration" do
      expect(Yast::BootStorage).to receive(:detect_disks)

      subject.propose
    end

    it "sets proposed flag" do
      expect(subject.proposed?).to eq false

      subject.propose

      expect(subject.proposed?).to eq true
    end
  end

  describe "#summary" do
    it "returns empty string" do
      expect(subject.summary).to eq([])
    end
  end

  describe "#packages" do
    context "live-installation" do
      before do
        allow(Yast::Mode).to receive(:live_installation).and_return(true)
      end

      it "returns empty package list" do
        expect(subject.packages).to eq([])
      end
    end

    context "kexec_reboot flag is not set" do
      before do
        allow(Yast::Linuxrc).to receive(:InstallInf)
          .with("kexec_reboot")
          .and_return("0")
      end

      it "returns empty package list" do
        expect(subject.packages).to eq([])
      end
    end

    context "kexec_reboot flag is set" do
      before do
        allow(Yast::Linuxrc).to receive(:InstallInf)
          .with("kexec_reboot")
          .and_return("1")
      end

      it "returns list containing kexec-tools package" do
        expect(subject.packages).to include("kexec-tools")
      end
    end
  end

  describe "#merge" do
    it "raises exception if different bootloader type passed" do
      subject.define_singleton_method(:name) { "funny_bootloader" }
      other = described_class.new
      other.define_singleton_method(:name) { "more_funny_bootloader" }

      expect { subject.merge(other) }.to raise_error(RuntimeError)
    end

    it "sets read flag if subject or passed one have it" do
      subject.define_singleton_method(:name) { "funny_bootloader" }
      other = described_class.new
      other.define_singleton_method(:name) { "funny_bootloader" }

      other.read

      subject.merge(other)
      expect(subject.read?).to eq true
    end

    it "sets propose flag if subject or passed one have it" do
      subject.define_singleton_method(:name) { "funny_bootloader" }
      other = described_class.new
      other.define_singleton_method(:name) { "funny_bootloader" }

      other.propose

      subject.merge(other)
      expect(subject.proposed?).to eq true
    end
  end
end
