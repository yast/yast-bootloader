#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/stage1"

Yast.import "Arch"
Yast.import "BootStorage"
Yast.import "Storage"

describe Bootloader::Stage1 do
  before do
    # simple mock getting disks from partition as it need initialized libstorage
    allow(subject).to receive(:can_use_boot?).and_return(true)
    mock_disk_partition
    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")

    # nasty hack to allow call of uninitialized libstorage as we do not want
    # to overmock Yast::Storage.GetDiskPartitionTg call
    Yast::Storage.instance_variable_set(:@sint, double(getPartitionPrefix: ""))
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

      expect(subject.devices).to eq ["/dev/vda"]
    end

    it "sets underlaying disks for md raid setup" do
      allow(Yast::BootStorage).to receive(:underlaying_devices).and_call_original
      Yast::BootStorage.instance_variable_set(:@underlaying_devices_cache, {})
      target_map_stub("storage_mdraid.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/md")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/md1")

      subject.propose

      expect(subject.devices).to eq ["/dev/vda", "/dev/vdb", "/dev/vdc", "/dev/vdd"]

      expect(subject.mbr?).to eq true
    end

    context "on ppc64" do
      before do
        allow(Yast::Arch).to receive(:architecture).and_return("ppc64")

        object_double(
          "Yast::BootStorage",
          prep_partitions: ["/dev/sda1", "/dev/sdb1", "/dev/sdc1"],
          detect_disks:    nil,
          disk_with_boot_partition: "/dev/sdb"
        ).as_stubbed_const

        subject.propose

        allow(Yast::Storage).to receive(:GetPartition).and_return({})
      end

      it "tries to use newly created partition at first" do
        expect(Yast::Storage).to receive(:GetPartition).with(anything, "/dev/sdc1")
          .and_return({"create" => true})

        subject.propose

        expect(subject.devices).to eq(["/dev/sdc1"])
      end

      it "then it tries to use partition on same disk as /boot" do
        expect(subject.devices).to eq(["/dev/sdb1"])
      end

      it "sets to device first available prep partition as fallback" do
        allow(Yast::BootStorage).to receive(:disk_with_boot_partition).and_return("/dev/sdd")
        subject.propose

        expect(subject.devices).to eq(["/dev/sda1"])
      end

    end

    it "sets no device for s390" do
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")

      subject.propose

      expect(subject.devices).to eq([])
    end
  end

  describe "#add_udev_device" do
    it "adds underlayed disk device for lvm disk" do
      allow(Yast::BootStorage).to receive(:underlaying_devices).and_call_original
      Yast::BootStorage.instance_variable_set(:@underlaying_devices_cache, {})
      target_map_stub("storage_lvm.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/system")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/system/root")
      allow(Yast::BootStorage).to receive(:RootPartitionDevice)
        .and_return("/dev/system/root")

      subject.add_udev_device("/dev/system")

      expect(subject.devices).to eq(["/dev/vda"])

      expect(subject.mbr?).to eq true
    end

    it "adds underlayed partition devices for lvm partition" do
      allow(Yast::BootStorage).to receive(:underlaying_devices).and_call_original
      Yast::BootStorage.instance_variable_set(:@underlaying_devices_cache, {})
      target_map_stub("storage_lvm.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/system")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/system/root")
      allow(Yast::BootStorage).to receive(:RootPartitionDevice)
        .and_return("/dev/system/root")

      subject.add_udev_device("/dev/system/root")

      expect(subject.devices).to eq(["/dev/vda3"])

      expect(subject.boot_partition?).to eq true
    end
  end

  describe "#can_use_boot?" do
    before do
      allow(subject).to receive(:can_use_boot?).and_call_original
    end

    it "returns false if boot partition fs is xfs" do
      target_map_stub("storage_xfs.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk).and_return("/dev/vda")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/vda1")

      expect(subject.can_use_boot?).to eq false
    end

    it "returns true otherwise" do
      target_map_stub("storage_tmpfs.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk).and_return("/dev/vda")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/vda1")

      expect(subject.can_use_boot?).to eq true

    end
  end
end
