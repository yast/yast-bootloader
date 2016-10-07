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

      expect{Bootloader::BootloaderFactory.system}.to raise_error(Bootloader::UnsupportedBootloader)
    end

    it "returns nil if sysconfig do not specify bootloader" do
      allow(Bootloader::Sysconfig).to receive(:from_system)
        .and_return(Bootloader::Sysconfig.new)

      expect(Bootloader::BootloaderFactory.system).to eq nil
    end
  end
end
