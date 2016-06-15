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
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
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
          prep_partitions:          ["/dev/sda1", "/dev/sdb1", "/dev/sdc1"],
          detect_disks:             nil,
          disk_with_boot_partition: "/dev/sdb"
        ).as_stubbed_const

        subject.propose

        allow(Yast::Storage).to receive(:GetPartition).and_return({})
      end

      it "tries to use newly created partition at first" do
        expect(Yast::Storage).to receive(:GetPartition).with(anything, "/dev/sdc1")
          .and_return("create" => true)

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

      it "activate partition if it is on DOS partition table" do
        expect(Yast::Storage).to receive(:GetDisk).with(anything, "/dev/sdb1")
          .and_return("label" => "dos")
        subject.propose

        expect(subject.activate?).to eq true
      end

      it "does not activate partition if it is on GPT" do
        expect(Yast::Storage).to receive(:GetDisk).with(anything, "/dev/sdb1")
          .and_return("label" => "gpt")
        subject.propose

        expect(subject.activate?).to eq false
      end
    end

    it "sets no device for s390" do
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")

      subject.propose

      expect(subject.devices).to eq([])
    end

    it "raise exception on unsupported architecture" do
      allow(Yast::Arch).to receive(:architecture).and_return("aarch64")

      expect { subject.propose }.to raise_error(RuntimeError)
    end
  end

  describe "#add_udev_device" do
    it "adds underlayed disk device for lvm disk" do
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
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
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
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

  describe "#available_locations" do
    context "on x86_64" do
      before do
        allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
        allow(subject).to receive(:can_use_boot?).and_call_original
      end

      it "returns map with :extended set to extended partition" do
        pending "need to get target map with /boot on logical partition"

        expect(subject.available_locations[:extended]).to eq "/dev/sda4"
      end

      it "returns map with :root if separated /boot is not available" do
        target_map_stub("storage_tmpfs.yaml")
        allow(Yast::BootStorage).to receive(:detect_disks).and_call_original
        Yast::BootStorage.detect_disks

        expect(subject.available_locations[:root]).to eq "/dev/vda1"
      end

      it "returns map with :boot if separated /boot is available" do
        target_map_stub("storage_mdraid.yaml")
        allow(Yast::BootStorage).to receive(:detect_disks).and_call_original
        Yast::BootStorage.detect_disks

        expect(subject.available_locations[:boot]).to eq "/dev/md1"
      end

      it "returns map without :boot nor :root when xfs used" do
        target_map_stub("storage_xfs.yaml")
        allow(Yast::BootStorage).to receive(:detect_disks).and_call_original
        Yast::BootStorage.detect_disks

        res = subject.available_locations

        expect(res).to_not include(:root)
        expect(res).to_not include(:boot)
      end
    end
  end
end
