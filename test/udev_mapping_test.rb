#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/udev_mapping"

describe Bootloader::UdevMapping do
  subject { Bootloader::UdevMapping }
  before do
    # always invalidate cache to use new mocks
    allow(subject.instance).to receive(:cache_valid?).and_return false
    allow(Yast::Arch).to receive(:ppc).and_return(false)
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
      expect {subject.to_kernel_device("/dev/disk/by-id/non-existing-device")}.to raise_error
    end
  end

  describe ".to_hash" do
    it "Returns mapping of udev devices to kernel devices" do
      target_map_stub("storage_ppc.rb")

      all_devices = subject.to_hash
      expect(all_devices["/dev/disk/by-id/ata-HITACHI_HTS723232A7A364_E3834563C86LDM-part1"]).to eq "/dev/sda1"
      expect(all_devices["/dev/disk/by-path/pci-0000:00:1f.2-scsi-0:0:0:0-part2"]).to eq "/dev/sda2"
      expect(all_devices["/dev/disk/by-id/wwn-0x5000cca6d4c3bbb8"]).to eq "/dev/sda"
    end
  end

  describe ".to_mountby_device" do
    before do
      # simple mock getting disks from partition as it need initialized libstorage
      allow(Yast::Storage).to receive(:GetDiskPartition) do |partition|
        case partition
        when "/dev/system/root"
          disk = "/dev/system"
          number = "system"
        when "/dev/mapper/cr_swap"
          disk = "/dev/mapper/cr_swap"
          number = ""
        when "tmpfs"
          disk = "tmpfs"
          number = ""
        else
          number = partition[/(\d+)$/, 1]
          disk = partition[0..-(number.size + 1)]
        end
        { "disk" => disk, "nr" => number }
      end
    end

    it "returns udev link in same format as used to its mounting" do
      target_map_stub("storage_lvm.rb")
      expect(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect(subject.to_mountby_device("/dev/vda1")).to eq "/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6"
    end

    it "respects partition specific mountby option" do
      target_map_stub("storage_lvm.rb")
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:id)

      expect(subject.to_mountby_device("/dev/vda2")).to eq "/dev/disk/by-uuid/ec8e9948-ca5f-4b18-a863-ac999365e4a9"
    end

    it "returns encrypted device name if device have it" do
      target_map_stub("storage_encrypted.rb")
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect(subject.to_mountby_device("/dev/mapper/cr_swap")).to eq "/dev/mapper/cr_swap"
    end

    it "returns kernel device name if requested udev mapping do not exists" do
      target_map_stub("storage_lvm.rb")
      expect(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:id)

      expect(subject.to_mountby_device("/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6")).to eq "/dev/vda1"
    end

    it "returns kernel device name for non-disk devices like tmpfs" do
      target_map_stub("storage_tmpfs.rb")

      expect(subject.to_mountby_device("tmpfs")).to eq "tmpfs"
    end

    it "returns kernel device name if device is mounted by device name" do
      target_map_stub("storage_tmpfs.rb")

      expect(subject.to_mountby_device("/dev/vda1")).to eq "/dev/vda1"
    end

    it "raises exception if unknown device passed" do
      target_map_stub("storage_lvm.rb")
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect {subject.to_mountby_device("/dev/non-exists")}.to raise_error
      expect {subject.to_mountby_device("/dev/disk-by-uuid/ffff-ffff-ffff-ffff")}.to raise_error
    end
  end
end


