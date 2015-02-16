require_relative "test_helper"

require "bootloader/device_map"

describe Bootloader::DeviceMap do
  subject { Bootloader::DeviceMap.new }

  describe "#to_hash" do
    it "returns hash with disks as keys and grub hd devices as values" do
      mapping = { "/dev/sda" => "hd0" }
      map = Bootloader::DeviceMap.new mapping
      expect(map.to_hash).to eq(mapping)
    end
  end

  describe "#propose" do
    before do
      allow(Yast::Arch).to receive(:s390).and_return(false)
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      target_map_stub("storage_mdraid.rb")
    end

    it "fills itself with device map proposal" do
      subject.propose
      expect(subject.to_hash).to_not be_empty
    end

    it "proposes device map with single disk containing stage1 for s390" do
      allow(Yast::Arch).to receive(:s390).and_return(true)

      subject.propose
      expect(subject.to_hash.size).to eq(1)
    end

    it "propose always empty map in Mode config" do
      allow(Yast::Mode).to receive(:config).and_return(true)

      subject.propose
      expect(subject.to_hash).to be_empty
    end

    # TODO: I do not have sufficient target map yet
    it "do not add to device map members of raids and multipath"

    it "do not add non-disk devices" do
      target_map_stub("storage_tmpfs.rb")

      subject.propose
      expect(subject.to_hash).to_not include("/dev/tmpfs")
    end

    # TODO: I do not have sufficient target map yet with enough disks and mixture of bios ids
    it "propose order according to bios id"

    # TODO: I do not have sufficient target map yet
    it "do not propose USB as first device"

    # TODO: I do not have sufficient target map yet with enough disks and mixture of bios ids
    it "propose as first device disk containing /boot"

    it "limit number of disks in device map to 8" do
      # simple mock getting disks from partition as it need initialized libstorage
      allow(Yast::Storage).to receive(:GetDiskPartition) do |partition|
        if partition == "/dev/system/root"
          disk = "/dev/system"
          number = "system"
        else
          number = partition[/(\d+)$/, 1]
          disk = partition[0..-(number.size + 1)]
        end
        { "disk" => disk, "nr" => number }
      end

      target_map_stub("many_disks.rb")

      subject.propose
      expect(subject.to_hash.size).to eq 8
    end

  end

  describe "#disks_order" do
    it "returns disks in device sorted by id" do
      map = Bootloader::DeviceMap.new(
        "/dev/vdb" => "hd0",
        "/dev/vda" => "hd2",
        "/dev/vdc" => "hd1"
      )

      expect(map.disks_order).to eq(["/dev/vdb", "/dev/vdc", "/dev/vda"])
    end
  end

  describe "#remapped_hash" do
    before do
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:id)
    end

    it "returns device map with keys mapped to mount_by option" do
      map = Bootloader::DeviceMap.new(
        "/dev/vdb" => "hd0",
        "/dev/vda" => "hd2",
        "/dev/vdc" => "hd1"
     )

      expect(Bootloader::UdevMapping).to receive(:to_kernel_device)
        .and_return("/dev/bla", "/dev/ble", "/dev/blabla")

      expect(map.remapped_hash).to eq(
        "/dev/bla"    => "hd0",
        "/dev/ble"    => "hd2",
        "/dev/blabla" => "hd1"
      )
    end

    it "returns not mapped map if mount_by is label and arch is not ppc" do
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:label)
      allow(Yast::Arch).to receive(:ppc).and_return(false)
      map = Bootloader::DeviceMap.new(
        "/dev/vdb" => "hd0",
        "/dev/vda" => "hd2",
        "/dev/vdc" => "hd1"
      )

      expect(Bootloader::UdevMapping).to_not receive(:to_kernel_device)

      expect(map.remapped_hash).to eq(map.to_hash)
    end
  end

  describe "#contain_disk?" do
    before do
      allow(Bootloader::UdevMapping).to receive(:to_mountby_device)
        .and_return("/dev/bla")
    end

    it "checks if device map contain passed disk" do
      map = Bootloader::DeviceMap.new(
        "/dev/vdb" => "hd0",
        "/dev/vda" => "hd2",
        "/dev/vdc" => "hd1"
      )

      expect(map.contain_disk?("/dev/vdb")).to be true
      expect(map.contain_disk?("/dev/vdd")).to be false
    end

    it "try also device in format for mountby" do
      map = Bootloader::DeviceMap.new(
        "/dev/bla" => "hd0"
      )

      expect(map.contain_disk?("/dev/bla")).to be true
    end
  end
end
