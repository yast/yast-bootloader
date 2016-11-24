require_relative "test_helper"

require "bootloader/grub2efi"

describe Bootloader::Grub2EFI do
  before do
    allow(::CFA::Grub2::Default).to receive(:new).and_return(double("GrubDefault").as_null_object)
    allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(double("GrubCfg").as_null_object)
    allow(Bootloader::Sections).to receive(:new).and_return(double("Sections").as_null_object)
    allow(Yast::BootStorage).to receive(:available_swap_partitions).and_return([])
    allow(Bootloader::GrubInstall).to receive(:new).and_return(double.as_null_object)
  end

  describe "#read" do
    it "reads secure boot configuration from sysconfig" do
      sysconfig = double(Bootloader::Sysconfig, secure_boot: true)
      expect(Bootloader::Sysconfig).to receive(:from_system).and_return(sysconfig)

      subject.read

      expect(subject.secure_boot).to eq true
    end
  end

  describe "write" do
    xit "setups protective mbr to real disks containing /boot/efi" do
      subject.pmbr_action = :add
      allow(Yast::BootStorage).to receive(:gpt_boot_disk?).and_return(true)
      allow(Yast::Storage).to receive(:GetEntryForMountpoint)
        .with("/boot/efi").and_return("device" => "/dev/md1")
      allow(Bootloader::Stage1Device).to receive(:new)
        .and_return(double(real_devices: ["/dev/sda", "/dev/sdb"]))

      expect(subject).to receive(:pmbr_setup).with("/dev/sda", "/dev/sdb")

      subject.write
    end

    xit "calls grub2-install with respective secure boot configuration" do
      # This test fails (only!) in Travis with
      # Failure/Error: subject.write Storage::Exception: Storage::Exception
      grub_install = double(Bootloader::GrubInstall)
      expect(grub_install).to receive(:execute).with(secure_boot: true)
      allow(Bootloader::GrubInstall).to receive(:new).and_return(grub_install)

      subject.secure_boot = true

      subject.write
    end

    xit "writes secure boot configuration to bootloader sysconfig" do
      # This test fails (only!) in Travis with
      # Failure/Error: subject.write Storage::Exception: Storage::Exception
      sysconfig = double(Bootloader::Sysconfig)
      expect(sysconfig).to receive(:write)
      expect(Bootloader::Sysconfig).to receive(:new)
        .with(bootloader: "grub2-efi", secure_boot: true)
        .and_return(sysconfig)

      subject.secure_boot = true

      subject.write
    end
  end

  context "#propose" do
    it "proposes to remove pmbr flag for disk" do
      subject.propose

      expect(subject.pmbr_action).to eq :remove
    end

    it "proposes to use secure boot for x86_64" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      subject.propose

      expect(subject.secure_boot).to eq true
    end

    it "proposes to not use secure boot for aarch64" do
      allow(Yast::Arch).to receive(:architecture).and_return("aarch64")
      subject.propose

      expect(subject.secure_boot).to eq false
    end
  end

  describe "#packages" do
    it "adds to list grub2-i386-efi on i386 architecture" do
      allow(Yast::Arch).to receive(:architecture).and_return("i386")

      expect(subject.packages).to include("grub2-i386-efi")
    end

    it "adds to list grub2-arm-efi on arm" do
      allow(Yast::Arch).to receive(:architecture).and_return("arm")

      expect(subject.packages).to include("grub2-arm-efi")
    end

    it "adds to list grub2-arm64-efi on aarch64" do
      allow(Yast::Arch).to receive(:architecture).and_return("aarch64")

      expect(subject.packages).to include("grub2-arm64-efi")
    end

    it "adds to list grub2-x86_64-efi on x86_64" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")

      expect(subject.packages).to include("grub2-x86_64-efi")
    end

    it "adds to list shim and mokutil on x86_64 with secure boot" do
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      subject.secure_boot = true

      expect(subject.packages).to include("shim")
      expect(subject.packages).to include("mokutil")
    end
  end

  describe "#summary" do
    it "returns line with boot loader type specified" do
      expect(subject.summary).to include("Boot Loader Type: GRUB2 EFI")
    end

    it "returns line with secure boot option specified" do
      subject.secure_boot = false

      expect(subject.summary).to include("Enable Secure Boot: no")
    end
  end

  describe "#merge" do
    it "overwrite secure boot if specified in merged one" do
      other = described_class.new
      other.secure_boot = true

      subject.secure_boot = false

      subject.merge(other)

      expect(subject.secure_boot).to eq true
    end
  end
end
