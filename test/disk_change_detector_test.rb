#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/disk_change_detector"

describe Bootloader::DiskChangeDetector do
  before do
    Yast.import "Storage"
    mount_points = { # TODO: full mock
      "/"     => ["/dev/sda1"],
      "/boot" => ["/dev/sda2"]
    }
    allow(Yast::Storage).to receive(:GetMountPoints).and_return(mount_points)

    Yast.import "BootStorage"
    allow(Yast::BootStorage).to receive(:extended_partition_for).and_return(nil)
  end

  after do
    Yast::BootCommon.globals["boot_boot"] = "false"
    Yast::BootCommon.globals["boot_root"] = "false"
    Yast::BootCommon.globals["boot_extended"] = "false"
    Yast::BootCommon.globals["boot_mbr"] = "false"
    Yast::BootCommon.globals["boot_custom"] = nil
    Yast::BootCommon.mbrDisk = nil
  end

  describe ".changes" do
    it "returns empty array if disk proposal do not change" do
      expect(subject.changes).to be_empty
    end

    it "returns list containing message with boot if device for /boot changed and stage1 selected for boot" do
      Yast::BootCommon.globals["boot_boot"] = "true"
      Yast::BootStorage.BootPartitionDevice = "/dev/sdb1"
      expect(subject.changes.first).to include('"/boot"')
    end

    it "returns list containing message with root if device for / changed and stage1 selected for root" do
      Yast::BootCommon.globals["boot_root"] = "true"
      Yast::BootStorage.RootPartitionDevice = "/dev/sdb2"
      expect(subject.changes.first).to include('"/"')
    end

    it "returns list containing message with extended if extended partition changed and stage1 selected for extended" do
      Yast::BootCommon.globals["boot_extended"] = "true"
      allow(Yast::BootStorage).to receive(:extended_partition_for).and_return("/dev/sda4")
      Yast::BootStorage.ExtendedPartitionDevice = "/dev/sdb2"
      expect(subject.changes.first).to include('"extended partition"')
    end

    it "returns list containing message with MBR if boot disk changed and stage1 selected for MBR" do
      Yast::BootCommon.globals["boot_mbr"] = "true"
      allow(Yast::BootCommon).to receive(:FindMBRDisk).and_return("/dev/sda")
      Yast::BootCommon.mbrDisk = "/dev/sdb"
      expect(subject.changes.first).to include("MBR")
    end

    it "returns list containing message with custom partition if custom boot disk changed and stage1 selected for custom" do
      Yast::BootCommon.globals["boot_custom"] = "/dev/sdc"
      allow(Yast::BootStorage).to receive(:possible_locations_for_stage1).and_return(["/dev/sda", "/dev/sda2"])
      expect(subject.changes.first).to include("custom bootloader partition")
    end
  end
end
