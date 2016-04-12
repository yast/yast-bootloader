require_relative "test_helper"

require "bootloader/main_dialog"

describe Bootloader::MainDialog do
  before do
    wizard = double.as_null_object
    stub_const("Yast::Wizard", wizard)

    sequencer = double.as_null_object
    stub_const("Yast::Sequencer", sequencer)

    allow(Yast::BootStorage).to receive(:bootloader_installable?).and_return(true)
  end

  describe "#run_auto" do
    it "creates dialog" do
      expect(Yast::Wizard).to receive(:CreateDialog)

      subject.run_auto
    end

    it "sets wizard buttons label" do
      expect(Yast::Wizard).to receive(:SetContentsButtons)

      subject.run_auto
    end

    it "sets window title and icon according to desktop file in running system" do
      expect(Yast::Wizard).to receive(:SetDesktopTitleAndIcon).with("bootloader")

      subject.run_auto
    end

    # TODO: have it in future as exception and allow user to do something with it like propose
    it "reports error when bootloader is not installable" do
      allow(Yast::BootStorage).to receive(:bootloader_installable?).and_return(false)

      expect(Yast::Report).to receive(:Error)

      subject.run_auto
    end

    it "runs configuration sequence" do
      # do not check params as it is so complex, that hardcoding it still
      # won't assure its correctness
      expect(Yast::Sequencer).to receive(:Run)

      subject.run_auto
    end

    it "closes dialog" do
      expect(Yast::Wizard).to receive(:CloseDialog)

      subject.run_auto
    end

    it "returns value from configuration sequence" do
      expect(Yast::Sequencer).to receive(:Run).and_return(:next)

      expect(subject.run_auto).to eq :next
    end
  end

  # TODO: duplicite, in fact just different sequencer configuration
  describe "#run" do
    it "creates dialog" do
      expect(Yast::Wizard).to receive(:CreateDialog)

      subject.run_auto
    end

    it "sets wizard buttons label" do
      expect(Yast::Wizard).to receive(:SetContentsButtons)

      subject.run_auto
    end

    it "sets window title and icon according to desktop file in running system" do
      expect(Yast::Wizard).to receive(:SetDesktopTitleAndIcon).with("bootloader")

      subject.run_auto
    end

    # TODO: have it in future as exception and allow user to do something with it like propose
    it "reports error when bootloader is not installable" do
      allow(Yast::BootStorage).to receive(:bootloader_installable?).and_return(false)

      expect(Yast::Report).to receive(:Error)

      subject.run_auto
    end

    it "runs configuration sequence including read and write screen" do
      # do not check params as it is so complex, that hardcoding it still
      # won't assure its correctness
      expect(Yast::Sequencer).to receive(:Run)

      subject.run_auto
    end

    it "closes dialog" do
      expect(Yast::Wizard).to receive(:CloseDialog)

      subject.run_auto
    end

    it "returns value from configuration sequence" do
      expect(Yast::Sequencer).to receive(:Run).and_return(:next)

      expect(subject.run_auto).to eq :next
    end
  end
end
