#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/stage1"

Yast.import "Arch"
Yast.import "BootStorage"

describe Bootloader::Stage1 do
  before do
    allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
  end

  describe "#propose" do
    xit "sets devices to proposed locations" do
      target_map_stub("storage_mdraid.yaml")
      subject.propose

      expect(subject.devices).to eq ["/dev/vda"]
    end

    xit "sets underlaying disks for md raid setup" do
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
      target_map_stub("storage_mdraid.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/md")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/md1")

      subject.propose

      expect(subject.devices).to eq ["/dev/vda", "/dev/vdb", "/dev/vdc", "/dev/vdd"]

      expect(subject.mbr?).to eq true
    end

    xit "do not set generic_mbr if proposed boot from mbr" do
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
      target_map_stub("storage_mdraid.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/md")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/md1")

      subject.propose

      expect(subject.generic_mbr?).to eq false
    end

    xcontext "on ppc64" do
      let(:sda) { double("Y2Storage::Disk", gpt?: true) }
      let(:sdb) { double("Y2Storage::Disk", gpt?: true) }
      let(:sdc) { double("Y2Storage::Disk", gpt?: true) }

      let(:sda1) do
        double("Y2Storage::Partition", name: "/dev/sda1", exists_in_probed?: true, partitionable: sda)
      end

      let(:sdb1) do
        double("Y2Storage::Partition", name: "/dev/sdb1", exists_in_probed?: true, partitionable: sdb)
      end

      let(:sdc1) do
        double("Y2Storage::Partition", name: "/dev/sdc1", exists_in_probed?: true, partitionable: sdc)
      end

      before do
        allow(Yast::Arch).to receive(:architecture).and_return("ppc64")

        object_double(
          "Yast::BootStorage",
          prep_partitions: [sda1, sdb1, sdc1],
          detect_disks:    nil
        ).as_stubbed_const

        subject.propose
      end

      it "tries to use newly created partition at first" do
        allow(sdc1).to receive(:exists_in_probed?).and_return(false)
        subject.propose

        expect(subject.devices).to eq(["/dev/sdc1"])
      end

      it "then it tries to use partition on same disk as /boot" do
        expect(subject.devices).to eq(["/dev/sdb1"])
      end

      it "sets to device first available prep partition as fallback" do
        subject.propose

        expect(subject.devices).to eq(["/dev/sda1"])
      end

      xit "sets udev link for device" do
        expect(Yast::Storage).to receive(:GetPartition).with(anything, "/dev/sdc1")
          .and_return("create" => true)

        expect(Bootloader::UdevMapping).to receive(:to_mountby_device).with("/dev/sdc1")
          .and_return("/dev/disk/by-id/partition1")

        subject.propose

        expect(subject.devices).to eq(["/dev/disk/by-id/partition1"])
      end

      it "activate partition if it is on DOS partition table" do
        allow(sdb).to receive(:gpt?).and_return(false)
        subject.propose

        expect(subject.activate?).to eq true
      end

      it "does not activate partition if it is on GPT" do
        subject.propose

        expect(subject.activate?).to eq false
      end
    end

    it "sets no device for s390" do
      allow(Yast::Arch).to receive(:architecture).and_return("s390_64")

      subject.propose

      expect(subject.devices).to eq([])
    end

    it "raise exception on unsupported architecture" do
      allow(Yast::Arch).to receive(:architecture).and_return("aarch64")

      expect { subject.propose }.to raise_error(RuntimeError)
    end
  end

  xdescribe "#add_udev_device" do
    it "adds underlayed disk device for lvm disk" do
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
      target_map_stub("storage_lvm.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/system")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/system/root")
      allow(Yast::BootStorage).to receive(:RootPartitionDevice)
        .and_return("/dev/system/root")

      subject.add_udev_device("/dev/system")

      expect(subject.devices).to eq(["/dev/vda"])

      expect(subject.mbr?).to eq true
    end

    it "adds underlayed partition devices for lvm partition" do
      allow(Bootloader::Stage1Device).to receive(:new).and_call_original
      target_map_stub("storage_lvm.yaml")

      allow(Yast::BootStorage).to receive(:mbr_disk)
        .and_return("/dev/system")
      allow(Yast::BootStorage).to receive(:BootPartitionDevice)
        .and_return("/dev/system/root")
      allow(Yast::BootStorage).to receive(:RootPartitionDevice)
        .and_return("/dev/system/root")

      subject.add_udev_device("/dev/system/root")

      expect(subject.devices).to eq(["/dev/vda3"])

      expect(subject.boot_partition?).to eq true
    end
  end

  describe "#can_use_boot?" do
    before do
      allow(subject).to receive(:can_use_boot?).and_call_original
      devicegraph_stub("complex-lvm-encrypt.yaml")
    end

    it "returns false if boot partition fs is xfs" do
      boot_partition = find_device("/dev/sda1")
      allow(Yast::BootStorage).to receive(:boot_mountpoint).and_return(boot_partition.filesystem)

      expect(subject.can_use_boot?).to eq false
    end

    it "returns false if boot partition is on lvm" do
      boot_partition = find_device("/dev/sde2")
      allow(Yast::BootStorage).to receive(:boot_mountpoint).and_return(boot_partition.filesystem)

      expect(subject.can_use_boot?).to eq false
    end

    it "returns false if boot partition is on md raid" do
      devicegraph_stub("md_raid.xml")
      boot_partition = find_device("/dev/md0")
      allow(Yast::BootStorage).to receive(:boot_mountpoint).and_return(boot_partition.filesystem)

      expect(subject.can_use_boot?).to eq false
    end

    it "returns false if boot partition is device for md raid" do
      devicegraph_stub("md_raid.xml")
      boot_partition = find_device("/dev/vdd2")
      allow(Yast::BootStorage).to receive(:boot_mountpoint).and_return(boot_partition.filesystem)

      expect(subject.can_use_boot?).to eq false
    end

    it "returns false if boot partition is encrypted" do
      boot_partition = find_device("/dev/sda4")
      allow(Yast::BootStorage).to receive(:boot_mountpoint).and_return(boot_partition.filesystem)

      expect(subject.can_use_boot?).to eq false
    end

    it "returns true otherwise" do
      boot_partition = find_device("/dev/sda2")
      allow(Yast::BootStorage).to receive(:boot_mountpoint).and_return(boot_partition.filesystem)

      expect(subject.can_use_boot?).to eq true
    end
  end

  describe "#available_locations" do
    context "on x86_64" do
      before do
        allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      end

      it "returns array with :boot if partition can be used for stage1" do
        devicegraph_stub("separate_boot.yaml")

        expect(subject.available_locations).to include(:boot)
      end

      it "returns array without :boot when xfs used" do
        devicegraph_stub("xfs.yaml")

        res = subject.available_locations

        expect(res).to_not include(:root)
        expect(res).to_not include(:boot)
      end
    end
  end
end
