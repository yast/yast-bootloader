require_relative "test_helper"

require "bootloader/stage1_device"

describe Bootloader::Stage1Device do

  before do
    # we really want to test this class in this test, so revert generic mock from helper
    allow(described_class).to receive(:new).and_call_original
  end

  describe "#real_devices" do
    it "returns itself in single element array for physical device as argument" do
      devicegraph_stub("storage_lvm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/vda1")
      expect(subject.real_devices).to eq(["/dev/vda1"])
    end

    it "returns underlaying disks where lvm partition lives for lvm disk" do
      devicegraph_stub("storage_lvm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/system")
      expect(subject.real_devices).to eq(["/dev/vda"])
    end

    it "returns partitions where lvm lives for lvm partition" do
      devicegraph_stub("storage_lvm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/system/root")
      expect(subject.real_devices).to eq(["/dev/vda3"])
    end

    xit "returns disks where lives /boot partitions for md raid disk" do
      target_map_stub("storage_mdraid.yaml")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/md1")

      subject = Bootloader::Stage1Device.new("/dev/md")
      expect(subject.real_devices).to eq(
        ["/dev/vda", "/dev/vdb", "/dev/vdc", "/dev/vdd"]
      )
    end

    xit "returns partitions which creates md raid for md raid partition" do
      target_map_stub("storage_mdraid.yaml")

      subject = Bootloader::Stage1Device.new("/dev/md1")
      expect(subject.real_devices).to eq(
        ["/dev/vda1", "/dev/vdb1", "/dev/vdc1", "/dev/vdd1"]
      )
    end

    xit "returns physical partitions where md raid lives for lvm partition on md raid" do
      target_map_stub("storage_lvm_on_mdraid.yaml")

      subject = Bootloader::Stage1Device.new("/dev/system/root")
      expect(subject.real_devices).to eq(
        ["/dev/vda1", "/dev/vdb1"]
      )
    end

    xit "returns physical disks where md raid lives for lvm disk on md raid" do
      target_map_stub("storage_lvm_on_mdraid.yaml")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice).and_return("/dev/system/root")

      subject = Bootloader::Stage1Device.new("/dev/system")
      expect(subject.real_devices).to eq(
        ["/dev/vda", "/dev/vdb"]
      )
    end

    xit "returns underlayed devices for dm main device" do
      target_map_stub("storage_dm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/mapper/pdc_dhigiadcde")
      expect(subject.real_devices).to eq(["/dev/sda"])
    end

    xit "returns underlayed devices for dm part device" do
      target_map_stub("storage_dm.yaml")

      subject = Bootloader::Stage1Device.new("/dev/mapper/pdc_dhigiadcde-part6")
      expect(subject.real_devices).to eq(["/dev/sda"])
    end

    it "skips disks used as partitionless lvm devices" do
      devicegraph_stub("lvm_whole_disk.yml")

      # FIXME won't be needed when boot_partition lazy loads
      Yast::BootStorage.detect_disks
      subject = Bootloader::Stage1Device.new("/dev/system")
      expect(subject.real_devices).to eq(["/dev/sda"])

      subject = Bootloader::Stage1Device.new("/dev/system/root")
      expect(subject.real_devices).to eq(["/dev/sda1"])
    end
  end
end
