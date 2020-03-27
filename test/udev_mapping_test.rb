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

      allow(device).to receive(:path_for_mount_by).with(mount_by).and_return(udev_name)
    end

    let(:device) { find_device("/dev/sda3") }

    let(:mount_by) { Y2Storage::Filesystems::MountByType.new(mount_by_option) }

    context "when the device is mounted" do
      before do
        device.filesystem.mount_point.mount_by = mount_by
      end

      let(:mount_by_option) { :label }

      context "and the udev name is available for the mount by option in the mount point" do
        let(:udev_name) { "/dev/disk/by-label/test" }

        it "returns the udev name according to the mount by option in the mount point" do
          expect(subject.to_mountby_device(device.name)).to eq(udev_name)
        end
      end

      context "and the udev name is not available for the mount by option in the mount point" do
        let(:udev_name) { nil }

        it "returns the kernel name as fallback" do
          expect(subject.to_mountby_device(device.name)).to eq("/dev/sda3")
        end
      end
    end

    context "when the device is not mounted" do
      before do
        device.filesystem&.remove_mount_point

        allow_any_instance_of(Y2Storage::MountPoint).to receive(:preferred_mount_by)
          .and_return(mount_by)
      end

      let(:mount_by_option) { :label }

      context "and the udev name is available for the preferred mount by option" do
        let(:udev_name) { "/dev/disk/by-label/test" }

        it "returns the udev name according to the preferred mount by option" do
          expect(subject.to_mountby_device(device.name)).to eq(udev_name)
        end
      end

      context "and the udev name is not available for the preferred mount by option" do
        let(:udev_name) { nil }

        it "returns the kernel name as fallback" do
          expect(subject.to_mountby_device(device.name)).to eq("/dev/sda3")
        end
      end
    end
  end
end
