require_relative "test_helper"

require "bootloader/stage1_device"

describe Bootloader::Stage1Device do

  before do
    # we really want to test this class in this test, so revert generic mock from helper
    allow(described_class).to receive(:new).and_call_original
  end

  describe "#real_devices" do
    before do
      # nasty hack to allow call of uninitialized libstorage as we do not want
      # to overmock Yast::Storage.GetDiskPartitionTg call
      Yast::Storage.instance_variable_set(:@sint, double(getPartitionPrefix: "").as_null_object)
    end

    it "returns itself in single element array for physical device as argument" do
      target_map_stub("storage_tmpfs.yaml")

      subject = Bootloader::Stage1Device.new("/dev/vda1")
      expect(subject.real_devices).to eq(["/dev/vda1"])
    end

    it "returns underlaying disks where lvm partition lives for lvm disk" do
      target_map_stub("storage_lvm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/system")
      expect(subject.real_devices).to eq(["/dev/vda"])
    end

    it "returns partitions where lvm lives for lvm partition" do
      target_map_stub("storage_lvm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/system/root")
      expect(subject.real_devices).to eq(["/dev/vda3"])
    end

    it "returns disks where lives /boot partitions for md raid disk" do
      target_map_stub("storage_mdraid.yaml")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/md1")

      subject = Bootloader::Stage1Device.new("/dev/md")
      expect(subject.real_devices).to eq(
        ["/dev/vda", "/dev/vdb", "/dev/vdc", "/dev/vdd"]
      )
    end

    it "returns partitions which creates md raid for md raid partition" do
      target_map_stub("storage_mdraid.yaml")

      subject = Bootloader::Stage1Device.new("/dev/md1")
      expect(subject.real_devices).to eq(
        ["/dev/vda1", "/dev/vdb1", "/dev/vdc1", "/dev/vdd1"]
      )
    end

    it "returns physical partitions where md raid lives for lvm partition on md raid" do
      target_map_stub("storage_lvm_on_mdraid.yaml")

      subject = Bootloader::Stage1Device.new("/dev/system/root")
      expect(subject.real_devices).to eq(
        ["/dev/vda1", "/dev/vdb1"]
      )
    end

    it "returns physical disks where md raid lives for lvm disk on md raid" do
      target_map_stub("storage_lvm_on_mdraid.yaml")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/system/root")

      subject = Bootloader::Stage1Device.new("/dev/system")
      expect(subject.real_devices).to eq(
        ["/dev/vda", "/dev/vdb"]
      )
    end

    it "skips disks used as partitionless lvm devices" do
      target_map_stub("lvm_whole_disk.yml")

      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/system/root")
      subject = Bootloader::Stage1Device.new("/dev/system")
      expect(subject.real_devices).to eq(["/dev/sda"])

      subject = Bootloader::Stage1Device.new("/dev/system/root")
      expect(subject.real_devices).to eq(["/dev/sda1"])
    end
  end


end
