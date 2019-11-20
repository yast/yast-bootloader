# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/main_dialog"

describe Bootloader::MainDialog do
  before do
    wizard = double.as_null_object
    stub_const("Yast::Wizard", wizard)

    @real_sequencer = Yast::Sequencer
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
      expect(Yast::Wizard).to receive(:SetDesktopTitleAndIcon).with("org.opensuse.yast.Bootloader")

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
      expect(Yast::Wizard).to receive(:SetDesktopTitleAndIcon).with("org.opensuse.yast.Bootloader")

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

    context "when no root filesystem is detected" do
      before do
        # Undo the global stub
        stub_const("Yast::Sequencer", @real_sequencer)
        allow(Bootloader::ReadDialog).to receive(:new).and_return double("ReadDialog", run: :next)

        allow(Yast::BootStorage).to receive(:boot_filesystem).and_raise(Bootloader::NoRoot)
      end

      it "reports the corresponding error" do
        expect(Yast::Report).to receive(:Error).with(/cannot configure the bootloader/)

        subject.run
      end

      it "returns :abort" do
        allow(Yast::Report).to receive(:Error)

        expect(subject.run).to eq :abort
      end
    end
  end
end
