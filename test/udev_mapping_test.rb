#! /usr/bin/env rspec --format doc
# frozen_string_literal: true

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
      expect(subject.to_kernel_device("/dev/disk/by-uuid/3de29985-8cc6-4c9d-8562-2ede26b0c5b6")).to eq "/dev/sda3"
    end

    it "raise exception if udev link is not known" do
      expect { subject.to_kernel_device("/dev/disk/by-id/non-existing-device") }.to raise_error(RuntimeError)
    end
  end

  describe ".to_mountby_device" do
    before do
      # find by name creates always new instance, so to make mocking easier, mock it to return always same instance
      allow(Y2Storage::BlkDevice).to receive(:find_by_name).and_return(device)
    end

    let(:device) { find_device("/dev/sda3") }

    context "when the device is formatted" do
      before do
        # The libstorage-ng bindings constantly create new instances of the storage objects.
        # To make mocking easier, mock it to return always the same instances
        allow(device).to receive(:filesystem).and_return(device.filesystem)
      end

      context "and mounted (or marked to be mounted)" do
        before do
          allow(device.filesystem).to receive(:mount_by_name).and_return mount_by_name
        end

        context "and the udev name is available for the mount_by option in the mount point" do
          let(:mount_by_name) { "/dev/something" }

          it "returns the udev name according to the mount_by option in the mount point" do
            expect(subject.to_mountby_device(device.name)).to eq mount_by_name
          end
        end

        context "and the udev name is not available for the mount by option in the mount point" do
          let(:mount_by_name) { nil }

          it "returns as fallback the name preferred by storage-ng" do
            expect(device.filesystem).to receive(:preferred_name).and_return "/dev/preferred/fs"

            expect(subject.to_mountby_device(device.name)).to eq "/dev/preferred/fs"
          end
        end
      end

      context "but not mounted" do
        before { device.filesystem&.remove_mount_point }

        it "returns the preferred udev name for the filesystem" do
          expect(device.filesystem).to receive(:preferred_name).and_return "/dev/preferred/fs"

          expect(subject.to_mountby_device(device.name)).to eq "/dev/preferred/fs"
        end
      end
    end

    context "when the device is not formatted" do
      before { device.remove_descendants }

      it "returns the preferred udev name for the block device" do
        expect(device).to receive(:preferred_name).and_return "/dev/preferred/blk_dev"

        expect(subject.to_mountby_device(device.name)).to eq "/dev/preferred/blk_dev"
      end
    end

    # Regression test for bsc#1166096
    context "for a regular PReP partition (contains no filesystem and is not mounted)" do
      before do
        # First, disable the general mocking
        allow(Y2Storage::BlkDevice).to receive(:find_by_name).and_call_original

        # Then, just stub the whole devicegraph to reproduce the scenario
        devicegraph_stub("bug_1166096.xml")
      end

      # These mocks are not needed
      let(:device) { nil }
      let(:mount_by) { nil }

      it "returns an udev link if there is any available" do
        expect(subject.to_mountby_device("/dev/vda1")).to eq "/dev/disk/by-path/pci-0000:00:06.0-part1"
      end
    end
  end
end
