require_relative "test_helper"

require "bootloader/proposal_client"

describe Bootloader::ProposalClient do
  describe "#description" do
    it "returns map with rich_text_title, menu_title and id" do
      result = subject.description

      expect(result.keys.sort).to eq ["id", "menu_title", "rich_text_title"]
    end
  end

  describe "#ask_user" do
    context "single click action is passed" do
      before do
        Yast.import "BootCommon"
        Yast.import "Bootloader"

        Yast::BootCommon.globals = {}
        Yast::Bootloader.proposed_cfg_changed = false
      end

      it "if id contain enable it enabled respective key" do
        subject.ask_user("chosen_id" => "enable_boot_mbr")

        expect(Yast::BootCommon.globals["boot_mbr"]).to eq "true"
      end

      it "if id contain disable it disabled respective key" do
        subject.ask_user("chosen_id" => "disable_boot_mbr")

        expect(Yast::BootCommon.globals["boot_mbr"]).to eq "false"
      end

      it "it returns \"workflow sequence\" with :next" do
        expect(subject.ask_user("chosen_id" => "disable_boot_mbr")).to(
          eq("workflow_sequence" => :next)
        )
      end

      it "sets to true that proposed cfg changed" do
        subject.ask_user("chosen_id" => "disable_boot_mbr")

        expect(Yast::Bootloader.proposed_cfg_changed).to be true
      end
    end

    context "gui id is passed" do
      before do
        Yast.import "Bootloader"

        allow(Yast::Bootloader).to receive(:Export).and_return({})
        Yast::Bootloader.proposed_cfg_changed = false
      end

      it "returns as workflow sequence result of GUI" do
        allow(subject).to receive(:BootloaderAutoSequence).and_return(:next)

        expect(subject.ask_user({})).to eq("workflow_sequence" => :next)
      end

      it "sets to true that poposed cfg changed if GUI changes are confirmed" do
        allow(subject).to receive(:BootloaderAutoSequence).and_return(:next)

        subject.ask_user({})

        expect(Yast::Bootloader.proposed_cfg_changed).to be true
      end

      it "restores previous configuration if GUI is canceled" do
        allow(subject).to receive(:BootloaderAutoSequence).and_return(:cancel)
        expect(Yast::Bootloader).to receive(:Import).with({})

        subject.ask_user({})
      end
    end
  end

  describe "#make_proposal" do
    before do
      Yast::BootCommon.setLoaderType("grub2")
      allow(Yast::Bootloader).to receive(:Propose)
      allow(Yast::Bootloader).to receive(:Summary).and_return("Summary")
      allow(Yast::BootCommon).to receive(:BootloaderInstallable).and_return(true)

      Yast.import "Arch"
      allow(Yast::Arch).to receive(:s390)
    end

    it "returns map with links set to single click actions" do
      expect(subject.make_proposal({})).to include("links")
    end

    it "returns map with raw_proposal set to respective bootloader summary" do
      expect(Yast::Bootloader).to receive(:Summary).and_return("Summary")

      expect(subject.make_proposal({})).to include("raw_proposal")
    end

    it "do not check installation errors if install on nfs" do
      expect(Yast::BootCommon).to receive(:getBootDisk).and_return("/dev/nfs")

      expect(subject.make_proposal({})).to_not include("warning")
    end

    it "report warning if no bootloader selected" do
      Yast::BootCommon.setLoaderType("none")

      result = subject.make_proposal({})

      expect(result["warning_level"]).to eq :warning
      expect(result["warning"]).to_not be_empty
    end

    it "report error if bootloader is not installable" do
      expect(Yast::BootCommon).to receive(:BootloaderInstallable).and_return(false)

      result = subject.make_proposal({})

      expect(result["warning_level"]).to eq :error
      expect(result["warning"]).to_not be_empty
    end

    it "reports error if system setup is not supported" do
      Yast.import "BootSupportCheck"
      expect(Yast::BootSupportCheck).to receive(:SystemSupported).and_return(false)
      expect(Yast::BootSupportCheck).to receive(:StringProblems).and_return("We have problem!")

      result = subject.make_proposal({})

      expect(result["warning_level"]).to eq :error
      expect(result["warning"]).to_not be_empty
    end

    it "call bootloader propose in common installation" do
      Yast.import "Mode"
      expect(Yast::Mode).to receive(:update).and_return(false)
      expect(Yast::Bootloader).to receive(:Propose)

      subject.make_proposal({})
    end

    it "reproprose from scrach during update if old bootloader is not grub2" do
      Yast.import "Mode"
      expect(Yast::Mode).to receive(:update).and_return(true)

      expect(subject).to receive("old_bootloader").and_return("grub").twice

      expect(Yast::BootCommon).to receive(:setLoaderType).with(nil)
      allow(Yast::BootCommon).to receive(:getLoaderType).and_return("grub2")
      expect(Yast::BootCommon).to receive(:setLoaderType).with("grub2")
      expect(Yast::Bootloader).to receive(:Reset).at_least(:once)
      expect(Yast::Bootloader).to receive(:Propose)

      subject.make_proposal({})
    end

    it "do not propose during update if if old bootloader is none" do
      Yast.import "Mode"
      expect(Yast::Mode).to receive(:update).and_return(true)

      expect(subject).to receive("old_bootloader").and_return("none").twice

      subject.make_proposal({})
    end

    it "just read old configuration update if old bootloader is grub2" do
      Yast.import "Mode"
      expect(Yast::Mode).to receive(:update).and_return(true)

      expect(subject).to receive("old_bootloader").and_return("grub2")

      expect(Yast::Bootloader).to_not receive(:Propose)
      expect(Yast::Bootloader).to receive(:blRead)

      subject.make_proposal({})
    end

    it "resets configuration if not automode and force_reset passed" do
      expect(Yast::Bootloader).to receive(:Reset)

      subject.make_proposal("force_reset" => true)
    end

    it "do not resets configuration in automode and even if force_reset passed" do
      Yast.import "Mode"
      expect(Yast::Mode).to receive(:autoinst).and_return(true)
      expect(Yast::Bootloader).to_not receive(:Reset)

      subject.make_proposal("force_reset" => true)
    end
  end
end
