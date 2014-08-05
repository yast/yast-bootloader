require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
  def target_map_stub(name)
    path = File.join(File.dirname(__FILE__), "data", name)
    tm = eval(File.read(path))
    allow(Yast::Storage).to receive(:GetTargetMap).and_return(tm)
  end

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
end
