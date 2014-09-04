require_relative "test_helper"

Yast.import "BootGRUB2"

# it should be probably part of BootStorage module, but we are too late in
# release phase, so place it here and adapt when location of this method changed
describe Yast::BootloaderGrub2MiscInclude do
  before do
    # simple mock getting disks from partition as it need initialized libstorage
    allow(Yast::Storage).to receive(:GetDiskPartition) do |partition|
      if partition == "/dev/system/root"
        disk = "/dev/system"
        number = "system"
      else
        number = partition[/(\d+)$/,1]
        disk = number ? partition[0..-(number.size+1)] : partition
      end
      { "disk" => disk, "nr" => number }
    end
    allow(Yast::Storage).to receive(:GetDeviceName) do |disk, partition|
      disk+partition.to_s
    end
  end


  def target_map_stub(name)
    path = File.join(File.dirname(__FILE__), "data", name)
    tm = eval(File.read(path))
    allow(Yast::Storage).to receive(:GetTargetMap).and_return(tm)
  end

  describe "#grub_getPartitionToActivate" do
    it "returns map with device, its disk and partition number" do
      target_map_stub("storage_mdraid.rb")
      result = Yast::BootGRUB2.grub_getPartitionToActivate("/dev/vda1")
      expected_result = {
        "mbr" => "/dev/vda",
        "num" => 1,
        "dev" => "/dev/vda1"
      }
      expect(result).to eq expected_result
    end

    it "returns underlaying devices for md raid" do
      target_map_stub("storage_mdraid.rb")
      result = Yast::BootGRUB2.grub_getPartitionToActivate("/dev/md1")
      expected_result = {
        "mbr" => "/dev/vda",
        "num" => 1,
        "dev" => "/dev/vda1"
      }
      expect(result).to eq expected_result

    end

    it "choose any partition except BIOS GRUB and swap partitions on disk if disk is passed" do
      target_map_stub("storage_lvm.rb")
      result = Yast::BootGRUB2.grub_getPartitionToActivate("/dev/vda")
      expected_result = {
        "mbr" => "/dev/vda",
        "num" => 3,
        "dev" => "/dev/vda3"
      }
      expect(result).to eq expected_result
    end

    it "return empty map if device do not exists" do
      target_map_stub("storage_lvm.rb")
      result = Yast::BootGRUB2.grub_getPartitionToActivate("/dev/nonexist")
      expected_result = {}
      expect(result).to eq expected_result
    end

    # TODO prepare test for extended partition, need target map containing it
  end
end
