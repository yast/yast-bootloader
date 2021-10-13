# frozen_string_literal: true

require_relative "test_helper"

require "bootloader/device_path"

describe Bootloader::DevicePath do
  subject(:dev_path) { Bootloader::DevicePath.new(param) }

  context "When activated with path for device file" do
    let(:param) { "/dev/sda1" }

    it "Stores the path as obtained" do
      expect(dev_path.path).to eql param
    end

    describe "#exists?" do
      it "succeedes for existing device" do
        allow(File).to receive(:exists?).with(param).and_return(true)
        expect(dev_path.exists?).to be true
      end

      it "fails for non existing device" do
        allow(File).to receive(:exists?).and_return(false)
        expect(Bootloader::DevicePath.new("/nonsense").exists?).to be false
      end
    end

    describe "#uuid?" do
      it "fails for real device path" do
        expect(dev_path.uuid?).to be false
      end
    end

    describe "#label?" do
      it "fails for real device path" do
        expect(dev_path.label?).to be false
      end
    end
  end

  context "When activated with UUID" do
    let(:uuid) { "00000000-1111-2222-3333-444444444444" }
    let(:param) { "UUID=\"#{uuid}\"" }
    let(:fs_path) { "/dev/disk/by-uuid/#{uuid}" }

    it "Converts UUID to fs path" do
      expect(dev_path.path).to eql fs_path
    end

    describe "#exists?" do
      it "succeedes for existing device" do
        allow(File).to receive(:exists?).with(fs_path).and_return(true)
        expect(dev_path.exists?).to be true
      end
    end

    describe "#uuid?" do
      it "succeedes" do
        expect(dev_path.uuid?).to be true
      end
    end

    describe "#label?" do
      it "fails for uuid activated path" do
        expect(dev_path.label?).to be false
      end
    end
  end

  context "When activated with UUID" do
    let(:label) { "OpenSUSE" }
    let(:param) { "LABEL=\"#{label}\"" }
    let(:fs_path) { "/dev/disk/by-label/#{label}" }

    it "Converts LABEL to fs path" do
      expect(dev_path.path).to eql fs_path
    end

    describe "#exists?" do
      it "succeedes for existing device" do
        allow(File).to receive(:exists?).with(fs_path).and_return(true)
        expect(dev_path.exists?).to be true
      end
    end

    describe "#uuid?" do
      it "fails for label activated path" do
        expect(dev_path.uuid?).to be false
      end
    end

    describe "#label?" do
      it "succeedes" do
        expect(dev_path.label?).to be true
      end
    end
  end
end
