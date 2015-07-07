#! /usr/bin/env rspec --format doc

require_relative "./test_helper"

require "bootloader/mbr_update"

describe Bootloader::MBRUpdate do
  subject { Bootloader::MBRUpdate.new }
  describe "#run" do
    before do
      globals = Yast::BootCommon.globals
      globals["activate"] = "false"
      globals["generic_mbr"] = "false"
      Yast::BootCommon.backup_mbr = false
      allow(Yast::BootStorage).to receive(:Md2Partitions).and_return({})

      mock_disk_partition

      allow(Yast::Storage).to receive(:GetDeviceName) do |dev, num|
        dev + num.to_s
      end

      # by default common architecture"
      allow(Yast::Arch).to receive(:architecture).and_return("x86_64")

      # fake query for gpt label
      allow(Yast::Storage).to receive(:GetTargetMap).and_return(
        double(:fetch => { "label" => "msdos" },
               :[]    => { "label" => "msdos" }
        )
      )
    end

    context "on s390" do
      before do
        allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
      end

      it "does nothing except returning true" do
        expect(Yast::WFM).to_not receive(:Execute)
        expect(Yast::SCR).to_not receive(:Execute)
        expect_any_instance_of(::Bootloader::BootRecordBackup).to_not(
          receive(:write)
        )
        expect(subject.run).to eq true
      end
    end

    context "BootCommon.backup_mbr config is not set" do
      before do
        Yast::BootCommon.backup_mbr = false
      end

      it "do not create any backup" do
        expect_any_instance_of(::Bootloader::BootRecordBackup).to_not(
          receive(:write)
        )
        subject.run
      end
    end

    context "BootCommon.backup_mbr config is set" do
      before do
        Yast::BootCommon.backup_mbr = true
        Yast::BootCommon.mbrDisk = "/dev/sda"
      end

      it "creates backup for BootCommon.mbrDisk" do
        backup_mock = double(::Bootloader::BootRecordBackup)
        expect(::Bootloader::BootRecordBackup).to(
          receive(:new).with("/dev/sda").and_return(backup_mock)
        )
        expect(backup_mock).to receive(:write)

        subject.run
      end

      # FIXME: get reason for it
      it "creates backup for all devices in BootCommon.GetBootloaderDevices if at least one device lies on mbrDisk" do
        expect(::Bootloader::BootRecordBackup).to(
          receive(:new).with("/dev/sda").and_return(double(:write => true))
        )

        allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
          .and_return(["/dev/sdb", "/dev/sda1"])
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

        subject.run
      end

      it "creates backup of any disk where Bootloader Devices laid in md raid" do
        allow(Yast::BootStorage).to receive(:Md2Partitions).and_return("/dev/sdb1" => "/dev/md0", "/dev/sda1" => "/dev/md0")

        allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
          .and_return(["/dev/md0"])
        backup_mock = double(::Bootloader::BootRecordBackup)
        expect(backup_mock).to receive(:write)
        expect(::Bootloader::BootRecordBackup).to(
          receive(:new).with("/dev/sdb").and_return(backup_mock)
        )
        expect(::Bootloader::BootRecordBackup).to(
          receive(:new).with("/dev/md0")
          .and_return(double(:write => true))
        )
        expect(::Bootloader::BootRecordBackup).to(
          receive(:new).with("/dev/sda")
          .and_return(double(:write => true))
        )

        subject.run
      end
    end

    context "activate and generic mbr is disabled" do
      before do
        globals = Yast::BootCommon.globals
        globals["activate"] = "false"
        globals["generic_mbr"] = "false"
      end

      it "do not write generic mbr anywhere" do
        expect(Yast::WFM).to_not receive(:Execute)
        expect(Yast::SCR).to_not receive(:Execute)
        subject.run
      end

      it "do not set boot and legacy boot flag anywhere" do
        expect(Yast::WFM).to_not receive(:Execute)
        expect(Yast::SCR).to_not receive(:Execute)
        subject.run
      end
    end

    context "when generic mbr is enabled" do
      before do
        Yast::BootCommon.globals["generic_mbr"] = "true"
        allow(Yast::Stage).to receive(:initial).and_return(false)
        allow(Yast::PackageSystem).to receive(:Install)
      end

      it "do nothing if mbrDisk is in Bootloader devices, so we install there bootloader stage1" do
        allow(Yast::BootCommon).to receive(:mbrDisk)
          .and_return("/dev/sda")
        allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
          .and_return(["/dev/sda"])

        expect(Yast::WFM).to_not receive(:Execute)
        expect(Yast::SCR).to_not receive(:Execute)
        subject.run
      end

      it "rewrites diskMBR with generic code" do
        allow(Yast::BootCommon).to receive(:mbrDisk)
          .and_return("/dev/sda")

        expect(Yast::SCR).to receive(:Execute).with(anything, /dd /).and_return("exit" => 0)
        subject.run
      end

      it "install syslinux if non on initial stage" do
        allow(Yast::Stage).to receive(:initial).and_return(false)
        expect(Yast::PackageSystem).to receive(:Install).with("syslinux")

        subject.run
      end

      it "install gpt generic code if disk is gpt" do
        allow(Yast::Storage).to receive(:GetTargetMap).and_return(
          "/dev/sda" => { "label" => "gpt" }
        )

        allow(Yast::BootCommon).to receive(:mbrDisk)
          .and_return("/dev/sda")

        expect(Yast::SCR).to receive(:Execute).with(anything, /gptmbr.bin/).and_return("exit" => 0)
        subject.run
      end
    end

    context "when activate is enabled" do
      before do
        Yast::BootCommon.globals["activate"] = "true"
        allow(Yast::Stage).to receive(:initial).and_return(false)
        allow(Yast::PackageSystem).to receive(:Install)
        allow(Yast::WFM).to receive(:Execute).and_return("exit" => 0, "stdout" => "")
      end

      context "disk label is DOS mbr" do
        before do
          allow(Yast::Storage).to receive(:GetTargetMap).and_return(
            double(:fetch => { "label" => "msdos" },
                   :[]    => { "label" => "msdos" }
            )
          )
        end

        it "sets boot flag on all partitions in Bootloader devices" do
          allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
            .and_return(["/dev/sda1", "/dev/sdb1"])

          expect(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 1 boot on/)
            .and_return("exit" => 0)
          subject.run
        end

        it "resets all old boot flags on disk before set boot flag" do
          allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
            .and_return(["/dev/sda1", "/dev/sdb1"])

          parted_output = "BYT;\n" \
                          "/dev/sda:500GB:scsi:512:4096:gpt:ATA WDC WD5000BPKT-7:;\n" \
                          "1:1049kB:165MB:164MB:fat16:primary:boot, legacy_boot;\n" \
                          "2:165MB:8760MB:8595MB:linux-swap(v1):primary:;\n" \
                          "3:8760MB:30.2GB:21.5GB:ext4:primary:boot;\n" \
                          "4:30.2GB:500GB:470GB:ext4:primary:legacy_boot;"

          allow(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -m \/dev\/sda print/)
            .and_return(
              "exit"   => 0,
              "stdout" => parted_output
            )
          expect(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 1 boot off/)
            .and_return(
              "exit"   => 0,
              "stdout" => parted_output
            )
          expect(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 3 boot off/)
            .and_return(
              "exit"   => 0,
              "stdout" => parted_output
            )

          subject.run
        end

        it "returns false if any setting of boot flag failed" do
          allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
            .and_return(["/dev/sda1", "/dev/sdb1"])

          allow(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 1 boot on/)
            .and_return("exit" => 1)

          expect(subject.run).to be false
        end
      end

      context "disk label is GPT" do
        before do
          allow(Yast::Storage).to receive(:GetTargetMap).and_return(
            double(:fetch => { "label" => "gpt" },
                   :[]    => { "label" => "gpt" }
            )
          )
        end

        it "sets legacy_boot flag on all partitions in Bootloader devices" do
          allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
            .and_return(["/dev/sda1", "/dev/sdb1"])

          expect(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 1 legacy_boot on/)
            .and_return("exit" => 0)
          subject.run
        end

        it "resets all old boot flags on disk before set boot flag" do
          allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
            .and_return(["/dev/sda1", "/dev/sdb1"])

          parted_output = "BYT;\n" \
                          "/dev/sda:500GB:scsi:512:4096:gpt:ATA WDC WD5000BPKT-7:;\n" \
                          "1:1049kB:165MB:164MB:fat16:primary:boot, legacy_boot;\n" \
                          "2:165MB:8760MB:8595MB:linux-swap(v1):primary:;\n" \
                          "3:8760MB:30.2GB:21.5GB:ext4:primary:boot;\n" \
                          "4:30.2GB:500GB:470GB:ext4:primary:legacy_boot;"

          allow(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -m \/dev\/sda print/)
            .and_return(
              "exit"   => 0,
              "stdout" => parted_output
            )
          expect(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 1 legacy_boot off/)
            .and_return(
              "exit"   => 0,
              "stdout" => parted_output
            )
          expect(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 4 legacy_boot off/)
            .and_return(
              "exit"   => 0,
              "stdout" => parted_output
            )

          subject.run
        end

        it "returns false if setting legacy_boot failed" do
          allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
            .and_return(["/dev/sda1", "/dev/sdb1"])

          allow(Yast::WFM).to receive(:Execute)
            .with(anything, /parted -s \/dev\/sda set 1 legacy_boot on/)
            .and_return("exit" => 1)

          expect(subject.run).to be false
        end
      end

      it "do not set any flag on old DOS MBR for logical partitions" do
        allow(Yast::BootCommon).to receive(:GetBootloaderDevices)
          .and_return(["/dev/sda1", "/dev/sdb6"])

        expect(Yast::WFM).to_not receive(:Execute)
          .with(anything, /sdb/)
        subject.run
      end

      it "sets flags also on /boot device if it is software raid" do
        allow(Yast::BootCommon).to receive(:getBootPartition).and_return("/dev/md1")

        expect(Yast::WFM).to receive(:Execute)
          .with(anything, /md set 1/)
        subject.run
      end
    end
  end
end
