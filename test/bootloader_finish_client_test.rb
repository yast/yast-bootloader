require_relative "test_helper"

require "bootloader/finish_client"
require "bootloader/bootloader_factory"
require "yast2/execute"

describe Bootloader::FinishClient do
  describe "#write" do
    before do
      Yast.import "Arch"

      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")

      Bootloader::BootloaderFactory.current_name = "grub2"
      Bootloader::BootloaderFactory.current.stage1.add_udev_device("/")
      @current_bl = Bootloader::BootloaderFactory.current
      allow(@current_bl).to receive(:read?).and_return(true)

      @system_bl = Bootloader::Grub2.new
      allow(Bootloader::BootloaderFactory).to receive(:system).and_return(@system_bl)
      allow(@system_bl).to receive(:merge)
      allow(@system_bl).to receive(:read)
      allow(@system_bl).to receive(:write)

      allow(Yast::Execute).to receive(:on_target)
    end

    it "sets on non-s390 systems reboot message" do
      Yast.import "Misc"

      subject.write

      expect(Yast::Misc.boot_msg).to match(/will reboot/)
    end

    it "sets on s390 systems reboot message if reipl return not different" do
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")

      expect(Yast::WFM).to receive(:ClientExists).and_return(true)
      expect(Yast::WFM).to receive(:call).and_return(
        "different" => false,
        "ipl_msg"   => ""
      )

      Yast.import "Misc"

      subject.write

      expect(Yast::Misc.boot_msg).to match(/will reboot/)
    end

    it "sets on s390 systems shut down message if reipl return different as true" do
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")

      expect(Yast::WFM).to receive(:ClientExists).and_return(true)
      expect(Yast::WFM).to receive(:call).and_return(
        "different" => true,
        "ipl_msg"   => "message"
      )

      Yast.import "Misc"

      subject.write

      expect(Yast::Misc.boot_msg).to match(/will now shut down/)
    end

    it "runs mkinitrd" do
      expect(Yast::Execute).to receive(:on_target).with("/sbin/mkinitrd")

      subject.write
    end

    it "merges system configuration with selected one in installation and set it as current" do
      expect(@system_bl).to receive(:merge).with(@current_bl)
      expect(::Bootloader::BootloaderFactory).to receive(:current=).with(@system_bl)

      subject.write
    end

    it "writes system configuration" do
      expect(@system_bl).to receive(:write)

      subject.write
    end

    it "returns true if everything goes as expect" do
      expect(subject.write).to eq true
    end

    context "in Mode update" do
      before do
        Yast.import "Mode"

        allow(Yast::Mode).to receive(:update).and_return(true)
      end

      it "does nothing if bootloader config is not read or proposed, so no changes done" do
        allow(@current_bl).to receive(:read?).and_return(false)
        allow(@current_bl).to receive(:proposed?).and_return(false)

        expect(@system_bl).to_not receive(:write)

        subject.write
      end
    end

    context "when kexec is requested" do
      before do
        allow(Yast::Linuxrc).to receive(:InstallInf).with("kexec_reboot")
          .and_return("1")
      end

      it "prepares kexec environment" do
        kexec = double
        expect(kexec).to receive(:prepare_environment)
        allow(::Bootloader::Kexec).to receive(:new).and_return(kexec)

        subject.write
      end
    end

    context "when there is no device to install grub" do
      before do
        Bootloader::BootloaderFactory.current.stage1.remove_device("/")
      end

      it "does not run mkinitrd" do
        expect(Yast::Execute).to_not receive(:on_target).with("/sbin/mkinitrd")

        subject.write
      end

      it "does not read nor write system configuration" do
        expect(@system_bl).to_not receive(:read)
        expect(@system_bl).to_not receive(:write)

        subject.write
      end
    end
  end
end
