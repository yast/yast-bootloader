require_relative "test_helper"

require "bootloader/finish_client"

describe Bootloader::FinishClient do
  describe "#write" do
    before do
      Yast.import "Arch"

      allow(Yast::Arch).to receive(:s390).and_return(false)

      Yast.import "Bootloader"

      allow(Yast::Bootloader).to receive(:WriteInstallation).and_return(true)
      allow(Yast::Bootloader).to receive(:Update).and_return(true)
      allow(Yast::WFM).to receive(:Execute)
        .and_return("exit" => 0, "stdout" => "", "stderr" => "")
      allow(Yast::SCR).to receive(:Execute)
      allow(Yast::Bootloader).to receive(:Read)
      allow(Yast::Bootloader).to receive(:FlagOnetimeBoot).and_return(true)
      allow(Yast::Bootloader).to receive(:getDefaultSection).and_return("linux")
    end

    it "sets on non-s390 systems reboot message" do
      Yast.import "Misc"

      subject.write

      expect(Yast::Misc.boot_msg).to match(/will reboot/)
    end

    it "sets on s390 systems reboot message if reipl return not different" do
      allow(Yast::Arch).to receive(:s390).and_return(true)

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
      allow(Yast::Arch).to receive(:s390).and_return(true)

      expect(Yast::WFM).to receive(:ClientExists).and_return(true)
      expect(Yast::WFM).to receive(:call).and_return(
        "different" => true,
        "ipl_msg"   => "message"
      )

      Yast.import "Misc"

      subject.write

      expect(Yast::Misc.boot_msg).to match(/will now shut down/)
    end

    context "in Mode update" do
      before do
        Yast.import "Mode"

        allow(Yast::Mode).to receive(:update).and_return(true)
      end

      it "mount bind /dev" do
        expect(Yast::WFM).to receive(:Execute)
          .with(Yast::Path.new(".local.bash_output"), /mount/)
          .and_return("exit" => 0, "stdout" => "", "stderr" => "")

        subject.write
      end

      it "calls Bootloader::Update" do
        expect(Yast::Bootloader).to receive(:Update)

        subject.write
      end

      it "return false if Bootloader::Update failed" do
        expect(Yast::Bootloader).to receive(:Update).and_return(false)

        expect(subject.write).to eq false
      end

      it "recreate initrd" do
        expect(Yast::SCR).to receive(:Execute).with(anything, "/sbin/mkinitrd")

        subject.write
      end
    end

    context "other modes" do
      it "calls Bootloader::WriteInstallation" do
        expect(Yast::Bootloader).to receive(:WriteInstallation)

        subject.write
      end

      it "return false if Bootloader::WriteInstallation failed" do
        expect(Yast::Bootloader).to receive(:WriteInstallation).and_return(false)

        expect(subject.write).to eq false
      end
    end

    context "grub2 based bootloader" do
      before do
        allow(Yast::Bootloader).to receive(:getLoaderType).and_return("grub2")
      end

      it "call first branding activator it found" do
        allow(::Dir).to receive(:[]).and_return(["/mnt/test"])
        allow(Yast::Installation).to receive(:destdir).and_return("/mnt")

        expect(Yast::SCR).to receive(:Execute).with(anything, "/test")

        subject.write
      end
    end

    it "reread configuration" do
      expect(Yast::Bootloader).to receive(:Read)

      subject.write
    end

    context "when kexec is requested" do
      before do
        allow(Yast::Linuxrc).to receive(:InstallInf).with("kexec_reboot")
          .and_return("1")
      end

      it "prepare kexec environment" do
        kexec = double
        expect(kexec).to receive(:prepare_environment)
        allow(::Bootloader::Kexec).to receive(:new).and_return(kexec)

        subject.write
      end
    end

    context "when kexec is not requested" do
      it "flag for one time boot default section" do
        expect(Yast::Bootloader).to receive(:FlagOnetimeBoot).and_return(true)

        subject.write
      end

      it "returns false if flagging failed" do
        expect(Yast::Bootloader).to receive(:FlagOnetimeBoot).and_return(false)

        expect(subject.write).to eq false
      end
    end

    it "return true if everything goes as expect" do
      expect(subject.write).to eq true
    end
  end
end
