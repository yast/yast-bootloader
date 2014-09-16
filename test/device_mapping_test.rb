#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/device_mapping"

describe Bootloader::DeviceMapping do
  subject { Bootloader::DeviceMapping }
  before do
    # always invalidate cache to use new mocks
    allow(subject.instance).to receive(:cache_valid?).and_return false
  end

  describe ".to_kernel_device" do
    before do
      target_map_stub("storage_ppc.rb")
    end

    it "return argument for non-udev mapped device names" do
      expect(subject.to_kernel_device("/dev/sda")).to eq "/dev/sda"
    end

    it "return kernel device name for udev mapped name" do
      expect(subject.to_kernel_device("/dev/disk/by-id/wwn-0x5000cca6d4c3bbb8")).to eq "/dev/sda"
    end

    it "raise exception if udev link is not known" do
      expect{subject.to_kernel_device("/dev/disk/by-id/non-existing-device")}.to raise_error
    end
  end

  describe ".to_mountby_device" do
    before do
      target_map_stub("storage_lvm.rb")
      # simple mock getting disks from partition as it need initialized libstorage
      allow(Yast::Storage).to receive(:GetDiskPartition) do |partition|
        if partition == "/dev/system/root"
          disk = "/dev/system"
          number = "system"
        else
          number = partition[/(\d+)$/,1]
          disk = partition[0..-(number.size+1)]
        end
        { "disk" => disk, "nr" => number }
      end
    end

    it "returns udev link in same format as used to its mounting" do
      expect(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect(subject.to_mountby_device("/dev/vda1")).to eq "/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6"
    end

    it "respects partition specific mountby option" do
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:id)

      expect(subject.to_mountby_device("/dev/vda2")).to eq "/dev/disk/by-uuid/ec8e9948-ca5f-4b18-a863-ac999365e4a9"
    end

    it "returns kernel device name if requested udev mapping do not exists" do
      expect(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:id)

      expect(subject.to_mountby_device("/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6")).to eq "/dev/vda1"
    end

    it "raises exception if unknown device passed" do
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect{subject.to_mountby_device("/dev/non-exists")}.to raise_error
      expect{subject.to_mountby_device("/dev/disk-by-uuid/ffff-ffff-ffff-ffff")}.to raise_error
    end
  end
end


