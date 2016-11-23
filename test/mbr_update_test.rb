#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/mbr_update"
require "bootloader/stage1"

Yast.import "BootStorage"

xdescribe Bootloader::MBRUpdate do
  subject { Bootloader::MBRUpdate.new }

  def stage1(devices: [], activate: false, generic_mbr: false)
    stage1 = Bootloader::Stage1.new

    devices.each { |d| stage1.model.add_device(d) }
    stage1.activate = activate
    stage1.generic_mbr = generic_mbr

    stage1
  end

  describe "#run" do
    before do
      mock_disk_partition

      allow(Yast::Storage).to receive(:GetDeviceName) do |dev, num|
        dev + num.to_s
      end

      # by default common architecture"
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")

      # fake query for gpt label
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(
        double(:fetch => { "label" => "msdos" },
               :[]    => { "label" => "msdos" })
      )
    end

    before do
      Yast::BootStorage.mbr_disk = "/dev/sda"
    end

    it "creates backup for BootStorage.mbr_disk" do
      backup_mock = double(::Bootloader::BootRecordBackup)
      expect(::Bootloader::BootRecordBackup).to(
        receive(:new).with("/dev/sda").and_return(backup_mock)
      )
      expect(backup_mock).to receive(:write)

      subject.run(stage1)
    end

    # FIXME: get reason for it
    it "creates backup for all devices in stage1" do
      expect(::Bootloader::BootRecordBackup).to(
        receive(:new).with("/dev/sda").and_return(double(:write => true))
      )

      backup_mock = double(::Bootloader::BootRecordBackup)
      expect(backup_mock).to receive(:write).twice
      expect(::Bootloader::BootRecordBackup).to(
        receive(:new).with("/dev/sdb")
        .and_return(backup_mock)
      )
      expect(::Bootloader::BootRecordBackup).to(
        receive(:new).with("/dev/sda1")
        .and_return(backup_mock)
      )

      subject.run(stage1(devices: ["/dev/sdb", "/dev/sda1"]))
    end

    context "activate and generic mbr is disabled" do
      before do
        allow(::Bootloader::BootRecordBackup)
          .to receive(:new).and_return(double(:write => true))
      end

      it "do not write generic mbr anywhere" do
        expect(Yast::Execute).to_not receive(:locally)
        expect(Yast::Execute).to_not receive(:on_target)
        subject.run(stage1(generic_mbr: false, activate: false))
      end

      it "do not set boot and legacy boot flag anywhere" do
        expect(Yast::Execute).to_not receive(:locally)
        expect(Yast::Execute).to_not receive(:on_target)
        subject.run(stage1(generic_mbr: false, activate: false))
      end
    end

    context "when generic mbr is enabled" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return(false)
        allow(Yast::PackageSystem).to receive(:Install)
        allow(::Bootloader::BootRecordBackup)
          .to receive(:new).and_return(double(:write => true))
      end

      it "do nothing if mbr_disk is in Bootloader devices, so we install there bootloader stage1" do
        allow(Yast::BootStorage).to receive(:mbr_disk)
          .and_return("/dev/sda")

        expect(Yast::Execute).to_not receive(:locally)
        expect(Yast::Execute).to_not receive(:on_target)
        subject.run(stage1(generic_mbr: true, devices: ["/dev/sda"]))
      end

      it "rewrites mbr_disk with generic code" do
        allow(Yast::BootStorage).to receive(:mbr_disk)
          .and_return("/dev/sda")

        expect(Yast::Execute).to receive(:locally) do |*args|
          return nil unless args.first =~ /dd/
          expect(args).to be_include("of=/dev/sda")
        end
        subject.run(stage1(generic_mbr: true))
      end

      it "always uses real devices" do
        allow(Yast::BootStorage).to receive(:mbr_disk)
          .and_return("/dev/md0")

        allow(::Bootloader::Stage1Device).to receive(:new).with("/dev/md0")
          .and_return(double(real_devices: ["/dev/sda1", "/dev/sdb1"]))
        expect(Yast::Execute).to receive(:locally).at_least(:twice) do |*args|
          next nil unless args.first =~ /dd/
          next nil unless args.include?("of=/dev/sdb")
          expect(args).to be_include("of=/dev/sda")
        end
        subject.run(stage1(generic_mbr: true))
      end

      it "install syslinux if not on initial stage" do
        allow(Yast::Stage).to receive(:initial).and_return(false)
        expect(Yast::PackageSystem).to receive(:Install).with("syslinux")

        subject.run(stage1(generic_mbr: true))
      end

      it "install gpt generic code if disk is gpt" do
        allow(Yast::Storage).to receive(:GetTargetMap).and_return(
          "/dev/sda" => { "label" => "gpt" }
        )

        allow(Yast::BootStorage).to receive(:mbr_disk)
          .and_return("/dev/sda")

        expect(Yast::Execute).to receive(:locally) do |*args|
          return nil unless args.first =~ /dd/
          expect(args.any? { |a| a =~ /if=.*gptmbr.bin/ }).to eq true
        end

        subject.run(stage1(generic_mbr: true))
      end
    end

    context "when activate is enabled" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return(false)
        allow(Yast::PackageSystem).to receive(:Install)
        allow(Yast::Execute).to receive(:locally).and_return("")
        allow(::Bootloader::BootRecordBackup)
          .to receive(:new).and_return(double(:write => true))
      end

      context "disk label is DOS mbr" do
        before do
          allow(Yast::Storage).to receive(:GetTargetMap).and_return(
            double(:fetch => { "label" => "msdos" },
                   :[]    => { "label" => "msdos" })
          )
        end

        it "sets boot flag on all stage1 partitions" do
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sda", "set", 1, "boot", "on")
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sdb", "set", 1, "boot", "on")

          subject.run(stage1(activate: true, devices: ["/dev/sda1", "/dev/sdb1"]))
        end

        it "resets all old boot flags on disk before set boot flag" do
          parted_output = "BYT;\n" \
                          "/dev/sda:500GB:scsi:512:4096:gpt:ATA WDC WD5000BPKT-7:;\n" \
                          "1:1049kB:165MB:164MB:fat16:primary:boot, legacy_boot;\n" \
                          "2:165MB:8760MB:8595MB:linux-swap(v1):primary:;\n" \
                          "3:8760MB:30.2GB:21.5GB:ext4:primary:boot;\n" \
                          "4:30.2GB:500GB:470GB:ext4:primary:legacy_boot;"

          allow(Yast::Execute).to receive(:locally)
            .with(/parted/, "-sm", "/dev/sda", "print", anything)
            .and_return(parted_output)

          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sda", "set", "1", "boot", "off")
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sda", "set", "3", "boot", "off")

          subject.run(stage1(activate: true, devices: ["/dev/sda1", "/dev/sdb1"]))
        end

        it "sets boot flag on boot device with the lowest bios id when stage1 partition is on md" do
          allow(Yast::Storage).to receive(:GetTargetMap).and_return(
            "/dev/sda" => { "label" => "msdos", "bios_id" => "0x81" },
            "/dev/sdb" => { "label" => "msdos", "bios_id" => "0x80" }
          )

          allow(::Bootloader::Stage1Device).to receive(:new).with("/dev/md1")
            .and_return(double(real_devices: ["/dev/sda1", "/dev/sdb1"]))
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sdb", "set", 1, "boot", "on")

          subject.run(stage1(activate: true, devices: ["/dev/md1"]))
        end
      end

      context "disk label is GPT" do
        before do
          allow(Yast::Storage).to receive(:GetTargetMap).and_return(
            double(:fetch => { "label" => "gpt" },
                   :[]    => { "label" => "gpt" })
          )
        end

        it "sets legacy_boot flag on all partitions in Bootloader devices" do
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sda", "set", 1, "legacy_boot", "on")
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sdb", "set", 1, "legacy_boot", "on")

          subject.run(stage1(activate: true, devices: ["/dev/sda1", "/dev/sdb1"]))
        end

        it "resets all old boot flags on disk before set boot flag" do
          parted_output = "BYT;\n" \
                          "/dev/sda:500GB:scsi:512:4096:gpt:ATA WDC WD5000BPKT-7:;\n" \
                          "1:1049kB:165MB:164MB:fat16:primary:boot, legacy_boot;\n" \
                          "2:165MB:8760MB:8595MB:linux-swap(v1):primary:;\n" \
                          "3:8760MB:30.2GB:21.5GB:ext4:primary:boot;\n" \
                          "4:30.2GB:500GB:470GB:ext4:primary:legacy_boot;"

          allow(Yast::Execute).to receive(:locally)
            .with(/parted/, "-sm", "/dev/sda", "print", anything)
            .and_return(parted_output)

          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sda", "set", "1", "legacy_boot", "off")
          expect(Yast::Execute).to receive(:locally)
            .with(/parted/, "-s", "/dev/sda", "set", "4", "legacy_boot", "off")

          subject.run(stage1(activate: true, devices: ["/dev/sda1", "/dev/sdb1"]))
        end
      end

      it "do not set any flag on old DOS MBR for logical partitions" do
        allow(Yast::Execute).to receive(:locally) do |*args|
          expect(args).to_not include("/dev/sdb")
          # empty return for quering parted
          ""
        end

        subject.run(stage1(activate: true, devices: ["/dev/sda1", "/dev/sdb6"]))
      end
    end
  end
end
