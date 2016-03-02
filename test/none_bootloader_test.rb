require_relative "test_helper"

require "bootloader/none_bootloader"

describe Bootloader::NoneBootloader do
  describe "#name" do
    it "returns \"none\"" do
      expect(subject.name).to eq "none"
    end
  end

  describe "#summary" do
    it "returns array with single element" do
      expect(subject.summary).to eq(["<font color=\"red\">Do not install any boot loader</font>"])
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
