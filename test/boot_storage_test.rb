require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
  subject { Yast::BootStorage }
  describe ".Md2Partitions" do
    it "returns map with devices creating virtual device as key and bios id as value" do
      target_map_stub("storage_mdraid.rb")
      result = subject.Md2Partitions("/dev/md1")
      expect(result).to include("/dev/vda1")
      expect(result).to include("/dev/vdb1")
      expect(result).to include("/dev/vdc1")
      expect(result).to include("/dev/vdd1")
    end

    it "returns empty map if device is not created from other devices" do
      target_map_stub("storage_mdraid.rb")
      result = subject.Md2Partitions("/dev/vda1")
      expect(result).to be_empty
    end
  end

  describe ".possible_locations_for_stage1" do
    let(:possible_locations) { subject.possible_locations_for_stage1 }
    before do
      target_map_stub("storage_mdraid.rb")
      allow(Yast::Arch).to receive(:s390).and_return(false) # be arch agnostic
      subject.device_map.propose
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:device)
    end

    it "returns list of kernel devices that can be used as stage1 for bootloader" do
      expect(possible_locations).to be_a(Array)
    end

    it "returns also physical disks" do
      expect(possible_locations).to include("/dev/vda")
    end

    it "returns all partitions suitable for stage1" do
      expect(possible_locations).to include("/dev/vda1")
    end

    it "do not return partitions if disk is not in device map" do
      subject.device_map = ::Bootloader::DeviceMap.new("/dev/vdb" => "hd0")

      res = subject.possible_locations_for_stage1
      expect(res).to_not include("/dev/vda1")
    end

    it "do not list partitions marked for delete" do
      partition_to_delete = Yast::Storage.GetTargetMap["/dev/vda"]["partitions"].first
      partition_to_delete["delete"] = true

      expect(possible_locations).to_not include(partition_to_delete["device"])
    end
  end

  describe ".real_disks_for_partition" do
    before do
      mock_disk_partition
    end

    it "returns unique list of disk on which partitions lives" do
      target_map_stub("storage_mdraid.rb")

      result = subject.real_disks_for_partition("/dev/vda1")
      expect(result).to include("/dev/vda")
    end

    it "can handle md raid" do
      target_map_stub("storage_mdraid.rb")

      result = subject.real_disks_for_partition("/dev/md1")
      expect(result).to include("/dev/vda")
      expect(result).to include("/dev/vdb")
      expect(result).to include("/dev/vdc")
      expect(result).to include("/dev/vdd")
    end

    it "can handle LVM" do
      target_map_stub("storage_lvm.rb")

      result = subject.real_disks_for_partition("/dev/system/root")
      expect(result).to include("/dev/vda")

      # do not crash if target map do not contain devices_add(bnc#891070)
      target_map_stub("storage_lvm_without_devices_add.rb")

      result = subject.real_disks_for_partition("/dev/system/root")
      expect(result).to include("/dev/vda")
    end
  end

  describe ".multipath_mapping" do
    before do
      mock_disk_partition
      # force reinit every time
      allow(subject).to receive(:checkCallingDiskInfo).and_return(true)
      # mock getting mount points as it need whole libstorage initialization
      allow(Yast::Storage).to receive(:GetMountPoints).and_return("/" => "/dev/vda1")
      # mock for same reason getting udev mapping
      allow(::Bootloader::UdevMapping).to receive(:to_mountby_device) do |arg|
        arg
      end
    end

    it "returns empty map if there is no multipath" do
      target_map_stub("storage_lvm.rb")

      # init variables
      subject.InitDiskInfo
      expect(subject.multipath_mapping).to eq({})
    end

    it "returns map of kernel names for disk devices to multipath devices associated with it" do
      target_map_stub("many_disks.rb")

      # init variables
      subject.InitDiskInfo
      expect(subject.multipath_mapping["/dev/sda"]).to eq "/dev/mapper/3600508b1001c9a84c91492de27962d57"
    end
  end

  describe ".detect_disks" do
    before do
      mock_disk_partition
      target_map_stub("storage_lvm.rb")

      allow(Yast::Storage).to receive(:GetMountPoints).and_return(
        "/"     => ["/dev/vda1"],
        "/boot" => ["/dev/vda2"]
      )
    end

    it "fills RootPartitionDevice variable" do
      subject.RootPartitionDevice = nil

      subject.detect_disks

      expect(subject.RootPartitionDevice).to eq "/dev/vda1"
    end

    it "fills BootPartitionDevice variable" do
      subject.BootPartitionDevice = nil

      subject.detect_disks

      expect(subject.BootPartitionDevice).to eq "/dev/vda2"
    end

    it "sets ExtendedPartitionDevice variable to nil if boot is not logical" do
      subject.ExtendedPartitionDevice = nil

      subject.detect_disks

      expect(subject.ExtendedPartitionDevice).to eq nil
    end

    # need target map with it
    it "sets ExtendedPartitionDevice variable to extended partition if boot is logical"

    it "raises exception if there is no mount point for root" do
      allow(Yast::Storage).to receive(:GetMountPoints).and_return({})

      expect { subject.detect_disks }.to raise_error
    end

    it "sets BootCommon.mbrDisk if not already set" do
      Yast::BootCommon.mbrDisk = nil

      expect(Yast::BootCommon).to receive(:FindMBRDisk).and_return("/dev/vda")

      subject.detect_disks

      expect(Yast::BootCommon.mbrDisk).to eq "/dev/vda"
    end

    it "returns true if bootloader devices is not yet set" do
      allow(Yast::BootCommon).to receive(:GetBootloaderDevices).and_return([])

      expect(subject.detect_disks).to eq true
    end

    it "returns true if any bootloader device is no longer available" do
      allow(Yast::BootCommon).to receive(:GetBootloaderDevices).and_return(["/dev/not_available"])
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect(subject.detect_disks).to eq true
    end

    it "returns false if all bootloader devices are available" do
      allow(Yast::BootCommon).to receive(:GetBootloaderDevices).and_return(["/dev/vda"])
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:uuid)

      expect(subject.detect_disks).to eq false
    end
  end
end
