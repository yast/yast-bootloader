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

  describe ".mbr_disk" do
    it "returns disk where lives /boot" do
      devicegraph_stub("trivial.yaml")

      expect(subject.mbr_disk).to eq find_device("/dev/sda")
    end
  end

  describe ".boot_partition" do
    it "returns /boot partition if it is separated" do
      devicegraph_stub("separate_boot.yaml")

      expect(subject.boot_partition).to eq find_device("/dev/sda2")
    end

    it "returns / partition if separated /boot does not exist" do
      devicegraph_stub("trivial.yaml")

      expect(subject.boot_partition).to eq find_device("/dev/sda3")
    end
  end

  describe ".root_partition" do
    it "returns / partition" do
      devicegraph_stub("trivial.yaml")

      expect(subject.root_partition).to eq find_device("/dev/sda3")
    end
  end

  describe ".extended_partition" do
    it "returns extended partition for .mbr_disk" do
      devicegraph_stub("logical.yaml")

      expect(subject.extended_partition).to eq find_device("/dev/sda2")
    end

    it "returns nil if there is no such partition" do
      devicegraph_stub("trivial_dos.yaml")

      expect(subject.extended_partition).to eq nil
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
end
