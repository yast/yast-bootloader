require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
  subject { Yast::BootStorage }

  describe ".prep_partitions" do
    it "returns the correct set of Y2Storage::Partition objects" do
      devicegraph_stub("prep_partitions.yml")
      partitions = subject.prep_partitions
      expect(partitions).to all(be_a(Y2Storage::Partition))
      expect(partitions.map(&:name)).to contain_exactly("/dev/sda2", "/dev/sdb2")
    end
  end

  xdescribe ".possible_locations_for_stage1" do
    let(:possible_locations) { subject.possible_locations_for_stage1 }
    before do
      target_map_stub("storage_mdraid.yaml")
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64") # be arch agnostic
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

  xdescribe ".detect_disks" do
    before do
      mock_disk_partition
      target_map_stub("storage_lvm.yaml")

      allow(Yast::Storage).to receive(:GetMountPoints).and_return(
        "/"     => ["/dev/vda1"],
        "/boot" => ["/dev/vda2"]
      )
      allow(Yast::Storage).to receive(:GetContVolInfo).and_return(false)
      # disable general mock for disk detection
      allow(subject).to receive(:detect_disks).and_call_original
      subject.RootPartitionDevice = ""
    end

    it "fills RootPartitionDevice variable" do
      subject.RootPartitionDevice = ""

      subject.detect_disks

      expect(subject.RootPartitionDevice).to eq "/dev/vda1"
    end

    it "fills BootPartitionDevice variable" do
      subject.BootPartitionDevice = ""

      subject.detect_disks

      expect(subject.BootPartitionDevice).to eq "/dev/vda2"
    end

    it "sets ExtendedPartitionDevice variable to nil if boot is not logical" do
      subject.ExtendedPartitionDevice = ""

      subject.detect_disks

      expect(subject.ExtendedPartitionDevice).to eq nil
    end

    # need target map with it
    it "sets ExtendedPartitionDevice variable to extended partition if boot is logical"

    it "raises exception if there is no mount point for root" do
      allow(Yast::Storage).to receive(:GetMountPoints).and_return({})

      expect { subject.detect_disks }.to raise_error(::Bootloader::NoRoot)
    end

    it "sets BootStorage.mbr_disk" do
      expect(subject).to receive(:find_mbr_disk).and_return("/dev/vda")

      subject.detect_disks

      expect(subject.mbr_disk).to eq "/dev/vda"
    end

    it "skips cache if storage gets changed" do
      subject.RootPartitionDevice = "/dev/sda1"
      subject.BootPartitionDevice = "/dev/sda2"
      subject.mbr_disk = "/dev/sda"

      allow(Yast::Storage).to receive(:GetTargetChangeTime).and_return(Time.now.to_i)

      subject.detect_disks

      expect(subject.RootPartitionDevice).to eq "/dev/vda1"
    end
  end

  xdescribe ".available_swap_partitions" do
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

  xdescribe ".encrypted_boot?" do
    it "returns true if /boot partition is on boot" do
      target_map_stub("storage_encrypted_two_levels.yaml")
      subject.BootPartitionDevice = "/dev/system/root"

      expect(subject.encrypted_boot?).to eq true
    end
  end
end
