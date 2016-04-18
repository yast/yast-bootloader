#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/stage1"

Yast.import "Arch"
Yast.import "BootStorage"
Yast.import "Storage"

describe Bootloader::Stage1 do
  before do
    # simple mock getting disks from partition as it need initialized libstorage
    allow(Yast::BootStorage).to receive(:can_boot_from_partition).and_return(true)
    mock_disk_partition
    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
  end

  describe "#propose" do
    it "sets devices to proposed locations" do
      target_map_stub("storage_mdraid.yaml")
      allow(Yast::BootStorage).to receive(:possible_locations_for_stage1)
        .and_return(["/dev/vda", "/dev/vda1"])
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/md1")
      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/vda")
      subject.propose

      expect(subject.devices).to eq ["/dev/md1"]
    end

    it "sets underlaying disks for md raid setup" do
      target_map_stub("storage_mdraid.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/md")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/md1")

      subject.propose

      expect(subject.devices).to eq ["/dev/vda", "/dev/vdb", "/dev/vdc", "/dev/vdd"]

      expect(subject.mbr?).to eq true
    end

    it "sets to device first available prep partition for ppc64" do
      allow(Yast::Arch).to receive(:architecture).and_return("ppc64")
      object_double(
        "Yast::BootStorage",
        prep_partitions: ["/dev/sda1"],
        detect_disks:    nil
      ).as_stubbed_const

      subject.propose

      expect(subject.devices).to eq(["/dev/sda1"])
    end

    it "sets no device for s390" do
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")

      subject.propose

      expect(subject.devices).to eq([])
    end
  end
end
