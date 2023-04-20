# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/bootloader_factory"

describe Bootloader::BootloaderFactory do
  describe "#system" do
    it "returns BootloaderBase instance according to name in system sysconfig" do
      allow(Bootloader::Sysconfig).to receive(:from_system)
        .and_return(Bootloader::Sysconfig.new(bootloader: "grub2"))

      expect(Bootloader::BootloaderFactory.system).to be_a(Bootloader::BootloaderBase)
    end

    it "raises exception if specified bootloader is not supported" do
      allow(Bootloader::Sysconfig).to receive(:from_system)
        .and_return(Bootloader::Sysconfig.new(bootloader: "grub"))

      expect { Bootloader::BootloaderFactory.system }.to raise_error(Bootloader::UnsupportedBootloader)
    end

    it "returns nil if sysconfig do not specify bootloader" do
      allow(Bootloader::Sysconfig).to receive(:from_system)
        .and_return(Bootloader::Sysconfig.new)

      expect(Bootloader::BootloaderFactory.system).to eq nil
    end
  end
  describe "#supported_names" do
    context "product supports systemd-boot" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeature).with("globals", "enable_systemd_boot").and_return(true)
      end
      it "returns systemd-boot in the list" do
        expect(Bootloader::BootloaderFactory.supported_names).to eq ["grub2", "grub2-efi", "systemd-boot", "none"]
      end
    end
    context "product does not support systemd-boot" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeature).with("globals", "enable_systemd_boot").and_return(false)
      end
      it "does not include systemd-boot in the list" do
        expect(Bootloader::BootloaderFactory.supported_names).to eq ["grub2", "grub2-efi", "none"]
      end
    end
  end
end
