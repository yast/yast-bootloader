# frozen_string_literal: true

require_relative "../test_helper"

require "cfa/systemd_boot"

describe CFA::SystemdBoot do
  subject(:selinux_config_file) do
    described_class.load(file_path: file_path, file_handler: file_handler)
  end

  let(:systemd_boot_path) { "loader.conf" }
  let(:file_handler) { File }
  let(:file_path) { File.join(DATA_PATH, "boot/efi/loader/loader.conf") }

  describe ".load" do
    context "when file exist" do
      it "creates an own Augeas instance using spacevars lens" do
        expect(::CFA::AugeasParser).to receive(:new).with("spacevars.lns").and_call_original

        described_class.load(file_path: file_path, file_handler: file_handler)
      end

      it "loads the file content" do
        file = described_class.load(file_path: file_path, file_handler: file_handler)

        expect(file.loaded?).to eq(true)
      end
    end

    context "when file does not exist" do
      let(:file_path) { "/file/not/created/yet" }

      it "creates an own Augeas instance using spacevars lens" do
        expect(::CFA::AugeasParser).to receive(:new).with("spacevars.lns").and_call_original

        described_class.load(file_path: file_path, file_handler: file_handler)
      end

      it "does not load the file content" do
        file = described_class.load(file_path: file_path, file_handler: file_handler)

        expect(file.loaded?).to eq(false)
      end
    end
  end

  describe "#initialize" do
    it "creates an own Augeas instance using spacevars lens" do
      expect(::CFA::AugeasParser).to receive(:new).with("spacevars.lns").and_call_original

      described_class.new(file_handler: file_handler)
    end
  end

  describe "#menu_timeout" do
    it "returns the timeout value" do
      expect(subject.menu_timeout).to eq("10")
    end
  end

  describe "#menu_timeout=" do
    it "sets the menu_timeout value" do
      expect { subject.menu_timeout = "15" }
        .to change { subject.menu_timeout }.from("10").to("15")
    end
  end

  describe "#save" do
    let(:timeout) { "20" }

    before do
      allow(Yast::SCR).to receive(:Write)
      allow(file_handler).to receive(:read).with(file_path)
        .and_return("# Some comment\ntimeout 5")
      subject.load
      subject.menu_timeout = timeout
    end

    it "writes changes to configuration file" do
      expect(file_handler).to receive(:write)
        .with(file_path, /.*timeout #{timeout}.*/)

      subject.save
    end
  end

end
