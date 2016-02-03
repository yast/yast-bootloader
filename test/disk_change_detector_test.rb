#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/disk_change_detector"
require "bootloader/stage1"

describe Bootloader::DiskChangeDetector do
  subject do
    stage1 = Bootloader::Stage1.new
    stage1.model.add_device("/dev/sda")
    described_class.new(stage1)
  end

  before do
    allow(Bootloader::UdevMapping).to receive(:to_kernel_device) { |a| a }
  end

  describe ".changes" do
    it "returns empty array if disk proposal do not change" do
      allow(Yast::BootStorage).to receive(:possible_locations_for_stage1).and_return(["/dev/sda", "/dev/sda2"])
      expect(subject.changes).to be_empty
    end

    it "returns list containing message if any stage1 device is no longer valid" do
      allow(Yast::BootStorage).to receive(:possible_locations_for_stage1).and_return(["/dev/sdb", "/dev/sdb2"])
      expect(subject.changes.first).to include("bootloader partition /dev/sda")
    end
  end
end
