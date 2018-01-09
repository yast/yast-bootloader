#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/udev_mapping"

describe Bootloader::UdevMapping do
  subject { Bootloader::UdevMapping }
  before do
    # Udev mapping is globally mocked in test_helper, so ensure here we test real method.
    allow(Bootloader::UdevMapping).to receive(:to_kernel_device).and_call_original
    allow(Bootloader::UdevMapping).to receive(:to_mountby_device).and_call_original
  end

  describe ".to_kernel_device" do
    before do
      # Y2Storage will ask libstorage-ng to perform a system lookup if the
      # device cannot be found using the information stored in the devicegraph.
      # Unfortunately, that operation misbehaves when executed in an
      # unprivileged Docker container, so we must mock the call.
      allow(Y2Storage::BlkDevice).to receive(:find_by_any_name).and_return nil
    end

    it "return argument for non-udev non-raid mapped device names" do
      expect(subject.to_kernel_device("/dev/sda")).to eq "/dev/sda"
    end

    it "returns the right device name in a multipath environment" do
      devicegraph_stub("multipath.xml")
      expect(subject.to_kernel_device("/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_001"))
        .to eq "/dev/mapper/0QEMU_QEMU_HARDDISK_001"
    end

    it "return kernel device name for udev mapped name" do
      expect(subject.to_kernel_device("/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6")).to eq "/dev/sda1"
    end

    it "raise exception if udev link is not known" do
      expect { subject.to_kernel_device("/dev/disk/by-id/non-existing-device") }.to raise_error(RuntimeError)
    end
  end

  describe ".to_mountby_device" do
    let(:device) { find_device("/dev/sda3") }

    before do
      # find by name creates always new instance, so to make mocking easier, mock it to return always same instance
      allow(Y2Storage::BlkDevice).to receive(:find_by_name).and_return(device)
    end

    it "returns udev link in same format as used to its mounting if defined" do
      allow(device).to receive(:blk_filesystem).and_return(
        double(
          mount_by: Y2Storage::Filesystems::MountByType.new(:uuid),
          uuid:     "3de29985-8cc6-4c9d-8562-2ede26b0c5b6"
        )
      )

      expect(subject.to_mountby_device(device.name)).to eq "/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6"
    end

    it "returns udev link by label if defined" do
      allow(device).to receive(:blk_filesystem).and_return(
        double(
          mount_by: Y2Storage::Filesystems::MountByType.new(:uuid),
          uuid:     nil,
          label:    "DATA"
        )
      )

      expect(subject.to_mountby_device(device.name)).to eq "/dev/disk/by-label/DATA"
    end

    it "returns udev link by uuid if defined" do
      allow(device).to receive(:blk_filesystem).and_return(
        double(
          mount_by: Y2Storage::Filesystems::MountByType.new(:label),
          uuid:     "3de29985-8cc6-4c9d-8562-2ede26b0c5b6",
          label:    ""
        )
      )

      expect(subject.to_mountby_device(device.name)).to eq "/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6"
    end

    it "returns first udev link by id if defined" do
      allow(device).to receive(:blk_filesystem).and_return(nil)
      allow(device).to receive(:udev_ids).and_return(["abc", "cde"])

      expect(subject.to_mountby_device(device.name)).to eq "/dev/disk/by-id/abc"
    end

    it "returns first udev link by path if defined" do
      allow(device).to receive(:blk_filesystem).and_return(nil)
      allow(device).to receive(:udev_paths).and_return(["abc", "cde"])

      expect(subject.to_mountby_device(device.name)).to eq "/dev/disk/by-path/abc"
    end

    it "returns kernel name as last fallback" do
      allow(device).to receive(:blk_filesystem).and_return(nil)

      expect(subject.to_mountby_device(device.name)).to eq device.name
    end
  end
end
