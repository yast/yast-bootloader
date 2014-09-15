require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
  describe ".Md2Partitions" do
    it "returns map with devices creating virtual device as key and bios id as value" do
      target_map_stub("storage_mdraid.rb")
      result = Yast::BootStorage.Md2Partitions("/dev/md1")
      expect(result).to include("/dev/vda1")
      expect(result).to include("/dev/vdb1")
      expect(result).to include("/dev/vdc1")
      expect(result).to include("/dev/vdd1")
    end

    it "returns empty map if device is not created from other devices" do
      target_map_stub("storage_mdraid.rb")
      result = Yast::BootStorage.Md2Partitions("/dev/vda1")
      expect(result).to be_empty
    end
  end

  describe ".real_disks_for_partition" do

    before do
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

    it "returns unique list of disk on which partitions lives" do
      target_map_stub("storage_mdraid.rb")

      result = Yast::BootStorage.real_disks_for_partition("/dev/vda1")
      expect(result).to include("/dev/vda")
    end

    it "can handle md raid" do
      target_map_stub("storage_mdraid.rb")

      result = Yast::BootStorage.real_disks_for_partition("/dev/md1")
      expect(result).to include("/dev/vda")
      expect(result).to include("/dev/vdb")
      expect(result).to include("/dev/vdc")
      expect(result).to include("/dev/vdd")
    end

    it "can handle LVM" do
      target_map_stub("storage_lvm.rb")

      result = Yast::BootStorage.real_disks_for_partition("/dev/system/root")
      expect(result).to include("/dev/vda")

      #do not crash if target map do not contain devices_add(bnc#891070)
      target_map_stub("storage_lvm_without_devices_add.rb")

      result = Yast::BootStorage.real_disks_for_partition("/dev/system/root")
      expect(result).to include("/dev/vda")
    end

  end

  describe ".changeOrderInDeviceMapping" do
    it "place priority device on top of device mapping" do
      device_map = { "/dev/sda" => "hd1", "/dev/sdb" => "hd0" }
      result = { "/dev/sda" => "hd0", "/dev/sdb" => "hd1" }
      expect(
        Yast::BootStorage.changeOrderInDeviceMapping(
          device_map,
          priority_device: "/dev/sda"
        )
      ).to eq(result)
    end

    it "ignores priority device which is not in device map already" do
      device_map = { "/dev/sda" => "hd1", "/dev/sdb" => "hd0" }
      result = { "/dev/sda" => "hd1", "/dev/sdb" => "hd0" }
      expect(
        Yast::BootStorage.changeOrderInDeviceMapping(
          device_map,
          priority_device: "/dev/system"
        )
      ).to eq(result)
    end

    it "place bad devices at the end of list" do
      device_map = { "/dev/sda" => "hd0", "/dev/sdb" => "hd1" }
      result = { "/dev/sda" => "hd1", "/dev/sdb" => "hd0" }
      expect(
        Yast::BootStorage.changeOrderInDeviceMapping(
          device_map,
          bad_devices: "/dev/sda"
        )
      ).to eq(result)
    end

    it "can mix priority and bad devices" do
      device_map = { "/dev/sda" => "hd0", "/dev/sdb" => "hd1", "/dev/sdc" => "hd2" }
      result = { "/dev/sda" => "hd2", "/dev/sdb" => "hd0", "/dev/sdc" => "hd1" }
      expect(
        Yast::BootStorage.changeOrderInDeviceMapping(
          device_map,
          bad_devices: "/dev/sda",
          priority_device: "/dev/sdb"
        )
      ).to eq(result)
    end
  end

  describe ".all_devices" do
    it "Returns mapping of udev devices to kernel devices" do
      target_map_stub("storage_ppc.rb")

      Bootloader::DeviceMapping.recreate_mapping
      all_devices = Yast::BootStorage.all_devices
      expect(all_devices["/dev/disk/by-id/ata-HITACHI_HTS723232A7A364_E3834563C86LDM-part1"]).to eq "/dev/sda1"
      expect(all_devices["/dev/disk/by-path/pci-0000:00:1f.2-scsi-0:0:0:0-part2"]).to eq "/dev/sda2"
      expect(all_devices["/dev/disk/by-id/wwn-0x5000cca6d4c3bbb8"]).to eq "/dev/sda"
    end
  end
end
