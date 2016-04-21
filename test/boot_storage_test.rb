require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
  subject { Yast::BootStorage }

  describe ".underlaying_devices" do
    before do
      # clear cache
      subject.instance_variable_set(:@underlaying_devices_cache, {})
      allow(subject).to receive(:underlaying_devices).and_call_original

      # nasty hack to allow call of uninitialized libstorage as we do not want
      # to overmock Yast::Storage.GetDiskPartitionTg call
      Yast::Storage.instance_variable_set(:@sint, double(getPartitionPrefix: "").as_null_object)
    end

    it "returns itself in single element array for physical device as argument" do
      target_map_stub("storage_tmpfs.yaml")

      expect(subject.underlaying_devices("/dev/vda1")).to eq(["/dev/vda1"])
    end

    it "returns underlaying disks where lvm partition lives for lvm disk" do
      target_map_stub("storage_lvm.yaml")

      expect(subject.underlaying_devices("/dev/system")).to eq(["/dev/vda"])
    end

    it "returns partitions where lvm lives for lvm partition" do
      target_map_stub("storage_lvm.yaml")

      expect(subject.underlaying_devices("/dev/system/root")).to eq(["/dev/vda3"])
    end

    it "returns disks where lives /boot partitions for md raid disk" do
      target_map_stub("storage_mdraid.yaml")
      allow(subject).to receive(:BootPartitionDevice).and_return("/dev/md1")

      expect(subject.underlaying_devices("/dev/md")).to eq(
        ["/dev/vda", "/dev/vdb", "/dev/vdc", "/dev/vdd"]
      )
    end

    it "returns partitions which creates md raid for md raid partition" do
      target_map_stub("storage_mdraid.yaml")

      expect(subject.underlaying_devices("/dev/md1")).to eq(
        ["/dev/vda1", "/dev/vdb1", "/dev/vdc1", "/dev/vdd1"]
      )
    end

    it "returns physical partitions where md raid lives for lvm partition on md raid" do
      target_map_stub("storage_lvm_on_mdraid.yaml")

      expect(subject.underlaying_devices("/dev/system/root")).to eq(
        ["/dev/vda1", "/dev/vdb1"]
      )
    end

    it "returns physical disks where md raid lives for lvm disk on md raid" do
      target_map_stub("storage_lvm_on_mdraid.yaml")
      allow(subject).to receive(:BootPartitionDevice).and_return("/dev/system/root")

      expect(subject.underlaying_devices("/dev/system")).to eq(
        ["/dev/vda", "/dev/vdb"]
      )
    end
  end

  describe ".possible_locations_for_stage1" do
    let(:possible_locations) { subject.possible_locations_for_stage1 }
    before do
      target_map_stub("storage_mdraid.yaml")
      allow(Yast::Arch).to receive(:s390).and_return(false) # be arch agnostic
      allow(Yast::Storage).to receive(:GetDefaultMountBy).and_return(:device)
      allow(Yast::Storage).to receive(:GetContVolInfo).and_return(false)
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

    it "do not list partitions marked for delete" do
      partition_to_delete = Yast::Storage.GetTargetMap["/dev/vda"]["partitions"].first
      partition_to_delete["delete"] = true

      expect(possible_locations).to_not include(partition_to_delete["device"])
    end
  end

  describe ".detect_disks" do
    before do
      mock_disk_partition
      target_map_stub("storage_lvm.yaml")

      allow(Yast::Storage).to receive(:GetMountPoints).and_return(
        "/"     => ["/dev/vda1"],
        "/boot" => ["/dev/vda2"]
      )
      allow(Yast::Storage).to receive(:GetContVolInfo).and_return(false)
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

      expect { subject.detect_disks }.to raise_error(RuntimeError)
    end

    it "sets BootStorage.mbr_disk" do
      expect(subject).to receive(:find_mbr_disk).and_return("/dev/vda")

      subject.detect_disks

      expect(subject.mbr_disk).to eq "/dev/vda"
    end
  end

  describe ".available_swap_partitions" do
    it "returns map of swap partitions and their size" do
      target_map_stub("storage_lvm.yaml")
      expect(subject.available_swap_partitions).to eq(
        "/dev/vda2" => 1_026_048
      )
    end

    it "returns crypt device name for encrypted swap" do
      target_map_stub("storage_encrypted.yaml")
      expect(subject.available_swap_partitions).to eq(
        "/dev/mapper/cr_swap" => 2_096_482
      )
    end
  end
end
