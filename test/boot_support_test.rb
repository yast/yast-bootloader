require_relative "test_helper"

Yast.import "BootSupportCheck"

describe Yast::BootSupportCheck do
  subject { Yast::BootSupportCheck }

  let(:bootloader) { Bootloader::BootloaderFactory.current }

  before do
    allow(Yast::SCR).to receive(:Execute)
  end

  describe "#StringProblems" do
    it "returns string with new line separated problems found by #SystemSupported" do
      Bootloader::BootloaderFactory.current_name = "grub2"
      allow(Yast::Arch).to receive(:architecture).and_return("aarch64")

      subject.SystemSupported()
      expect(subject.StringProblems()).to_not be_empty
    end
  end

  describe "#SystemSupported" do
    it "always return true for none bootloader" do
      Bootloader::BootloaderFactory.current_name = "none"
      expect(subject.SystemSupported).to eq true
    end

    context "x86_64" do
      before do
        allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
        Bootloader::BootloaderFactory.current_name = "grub2"
      end

      it "returns false if grub2-efi is used and efi not supported" do
        Bootloader::BootloaderFactory.current_name = "grub2-efi"
        allow(Yast::FileUtils).to receive(:Exists).and_return(false)

        expect(subject.SystemSupported).to eq false
      end

      it "returns false if neither generic mbr nor grub2 mbr is written" do
        allow(bootloader).to receive(:stage1)
          .and_return(double(mbr?: false, model: double(generic_mbr?: false, activate?: false)))

        expect(subject.SystemSupported).to eq false
      end

      it "returns false if no partition have boot flag and its write is not set" do
        allow(bootloader).to receive(:stage1)
          .and_return(double(mbr?: false, model: double(activate?: false, generic_mbr?: true)))
        allow(Yast::Storage).to receive(:GetBootPartition).and_return(nil)

        expect(subject.SystemSupported).to eq false
      end
    end
  end
end
