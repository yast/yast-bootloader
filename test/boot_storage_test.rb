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

  describe ".possible_locations_for_stage1" do
    before do
      target_map_stub("storage_mdraid.rb")
      # won't work without device map
      Yast::BootStorage.ProposeDeviceMap
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:device)
    end

    it "returns list of kernel devices that can be used as stage1 for bootloader" do
      res = Yast::BootStorage.possible_locations_for_stage1
      expect(res).to be_a(Array)
    end

    it "returns also physical disks" do
      res = Yast::BootStorage.possible_locations_for_stage1
      expect(res).to include("/dev/vda")
    end

    it "returns all partitions suitable for stage1" do
      res = Yast::BootStorage.possible_locations_for_stage1
      expect(res).to include("/dev/vda1")
    end

    it "do not return partitions if disk is not in device map" do
      Yast::BootStorage.device_mapping = { "/dev/vdb" => "hd0" }

      res = Yast::BootStorage.possible_locations_for_stage1
      expect(res).to_not include("/dev/vda1")
    end

    it "do not list partitions marked for delete" do
      partition_to_delete = Yast::Storage.GetTargetMap["/dev/vda"]["partitions"].first
      partition_to_delete["delete"] = true

      res = Yast::BootStorage.possible_locations_for_stage1
      expect(res).to_not include(partition_to_delete["device"])
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
end
