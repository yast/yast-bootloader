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
      it "install packages listed required by bootloader from packages method" do
        expect(Yast::PackageSystem).to receive(:InstallAll).with(["kexec-tools"])

        subject.write
      end
    end
  end

  describe "#read" do
    before do
      allow(Yast::BootStorage).to receive(:detect_disks)
    end

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
end
