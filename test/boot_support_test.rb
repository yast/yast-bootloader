# frozen_string_literal: true

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
        allow(Bootloader::Systeminfo).to receive(:efi_mandatory?).and_return(false)
      end

      it "returns false if neither generic mbr nor grub2 mbr is written" do
        allow(bootloader).to receive(:stage1)
          .and_return(double(mbr?: false, generic_mbr?: false, activate?: false))

        expect(subject.SystemSupported).to eq false
      end
      xit "returns false if no partition have boot flag and its write is not set" do
        allow(bootloader).to receive(:stage1)
          .and_return(double(mbr?: false, activate?: false, generic_mbr?: true))
        allow(Yast::Storage).to receive(:GetBootPartition).and_return(nil)

        expect(subject.SystemSupported).to eq false
      end

      context "UEFI is not supported" do
        before do
          allow(Bootloader::Systeminfo).to receive(:efi?).and_return(false)
        end

        it "returns false if grub2-efi is used" do
          Bootloader::BootloaderFactory.current_name = "grub2-efi"

          expect(subject.SystemSupported).to eq false
        end

        it "returns false if grub2-bls is used" do
          Bootloader::BootloaderFactory.current_name = "grub2-bls"

          expect(subject.SystemSupported).to eq false
        end

        it "returns false if systemd-boot is used" do
          Bootloader::BootloaderFactory.current_name = "systemd-boot"
          allow(subject).to receive(:efi?).and_return(false)

          expect(subject.SystemSupported).to eq false
        end
      end

      context "UEFI is supported" do
        before do
          allow(Bootloader::Systeminfo).to receive(:efi?).and_return(true)
        end

        context "there is not other installed system" do
          before do
            allow_any_instance_of(Y2Storage::DiskAnalyzer).to receive(:installed_systems).and_return([])
          end

          it "returns true if grub2-bls is used" do
            Bootloader::BootloaderFactory.current_name = "grub2-bls"

            expect(subject.SystemSupported).to eq true
            expect(subject.StringProblems()).to be_empty
          end
        end

        context "there is another installed system" do
          before do
            allow_any_instance_of(Y2Storage::DiskAnalyzer).to receive(:installed_systems).and_return(["window"])
          end

          it "returns false if grub2-bls is used" do
            Bootloader::BootloaderFactory.current_name = "grub2-bls"

            expect(subject.SystemSupported).to eq false
            expect(subject.StringProblems()).to_not be_empty
          end
        end
      end
    end
  end
end
