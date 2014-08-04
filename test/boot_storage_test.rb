require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
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
