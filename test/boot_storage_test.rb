require_relative "test_helper"

Yast.import "BootStorage"

describe Yast::BootStorage do
  subject { Yast::BootStorage }

  describe ".prep_partitions" do
    it "returns the correct set of Y2Storage::Partition objects" do
      devicegraph_stub("prep_partitions.yaml")
      partitions = subject.prep_partitions
      expect(partitions).to all(be_a(Y2Storage::Partition))
      expect(partitions.map(&:name)).to contain_exactly("/dev/sda2", "/dev/sdb2")
    end
  end

  describe ".available_swap_partitions" do
    it "returns map of swap partitions and their size" do
      devicegraph_stub("trivial.yaml")
      expect(subject.available_swap_partitions).to eq(
        "/dev/sda2" => 1_026_048
      )
    end

    it "returns crypt device name for encrypted swap" do
      devicegraph_stub("complex-lvm-encrypt.yaml")
      expect(subject.available_swap_partitions).to eq(
        "/dev/mapper/cr_swap" => 2_095_104
      )
    end
  end

  describe ".encrypted_boot?" do
    it "returns true if /boot partition is on boot" do
      devicegraph_stub("complex-lvm-encrypt.yaml")

      expect(subject.encrypted_boot?).to eq true
    end
  end

  describe ".boot_disks" do
    it "it contain only multipath device without wires" do
      devicegraph_stub("multipath.xml")

      expect(subject.boot_disks.map(&:name)).to eq(["/dev/mapper/0QEMU_QEMU_HARDDISK_001"])
    end
  end

  describe ".extended_for_logical" do
    before do
      devicegraph_stub("logical.yaml")
    end

    it "returns partition itself if it is not logical" do
      partition = find_device("/dev/sda1")
      expect(subject.extended_for_logical(partition)).to eq partition
    end
    it "return extended partion for logical partition" do
      partition = find_device("/dev/sda5")
      expect(subject.extended_for_logical(partition)).to eq find_device("/dev/sda2")
    end
  end
end
