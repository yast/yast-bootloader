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

  describe ".stage1_devices_for_name" do
    it "raises BrokenConfiguration exception if gets unknown name" do
      # mock staging graph as graph does not return proper value when run as non-root
      allow(subject.staging).to receive(:find_by_any_name).and_return(nil)

      expect { subject.stage1_devices_for_name("/dev/non-existing") }.to(
        raise_error(::Bootloader::BrokenConfiguration)
      )
    end
  end

  describe ".boot_disks" do
    context "intel RSTe" do
      before do
        devicegraph_stub("intel_rst.xml")
      end

      it "returns md raid disk device where /boot lives" do
        expect(subject.boot_disks.map(&:name)).to eq ["/dev/md/Volume0_0"]
      end
    end
  end

  describe ".boot_partitions" do
    context "intel RSTe" do
      before do
        devicegraph_stub("intel_rst.xml")
      end

      it "returns md raid partitions device where /boot lives" do
        expect(subject.boot_partitions.map(&:name)).to eq ["/dev/md/Volume0_0p5"]
      end
    end
  end
end
