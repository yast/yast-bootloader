#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/device_mapping"

describe Bootloader::DeviceMapping do
  subject { Bootloader::DeviceMapping }

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
end


