require_relative "test_helper"

Yast.import "Bootloader"

describe Yast::Bootloader do
  subject { Yast::Bootloader }

  describe ".Import" do
    before do
      # ensure flags are reset
      Yast::BootCommon.was_read = false
      Yast::BootCommon.was_proposed = false
      Yast::BootCommon.changed = false
      Yast::BootCommon.location_changed = false
    end

    # FIXME: looks useless as import is used in autoinstallation and in such case reset do nothing
    it "resets configuration" do
      expect(subject).to receive(:Reset)

      subject.Import({})
    end

    it "marks that configuration is read" do
      subject.Import({})

      expect(Yast::BootCommon.was_read).to eq true
    end

    it "marks that configuration is already proposed" do
      subject.Import({})

      expect(Yast::BootCommon.was_proposed).to eq true
    end

    it "marks that configuration is changed" do
      subject.Import({})

      expect(Yast::BootCommon.changed).to eq true
    end

    it "marks that stage1 location changed" do
      subject.Import({})

      expect(Yast::BootCommon.location_changed).to eq true
    end

    it "sets bootloader from key \"loader_type\"" do
      expect(Yast::BootCommon).to receive(:setLoaderType).with("grub2")
      subject.Import("loader_type" => "grub2")
    end

    it "sets proposed bootloader if not set in data" do
      expect(Yast::BootCommon).to receive(:setLoaderType).with(Yast::BootCommon.getLoaderType(true))
      subject.Import({})
    end

    it "acts like missing if \"loader_type\" value is empty" do
      expect(Yast::BootCommon).to receive(:setLoaderType).with(Yast::BootCommon.getLoaderType(true))
      subject.Import("loader_type" => "")
    end

    it "pass initrd specific map to initrd module" do
      initrd_map = {
        "list"     => ["nouveau", "nvidia"],
        "settings" => {
          "nouveau" => {
            "debug" => "1"
          }
        }
      }
      expect(Yast::Initrd).to receive(:Import).with(initrd_map)

      subject.Import("initrd" => initrd_map)
    end

    it "sets passed \"write_settings\" map" do
      write_settings = { "key" => "value" }

      subject.Import("write_settings" => write_settings)
      expect(Yast::BootCommon.write_settings).to eq write_settings
    end
  end

  describe ".ReadOrProposeIfNeeded" do
    before do
      allow(subject).to receive(:Propose)
      allow(subject).to receive(:Read)
      Yast::BootCommon.was_read = false
      Yast::BootCommon.was_proposed = false
    end

    it "does nothing if already read" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to_not receive(:Read)
      Yast::BootCommon.was_read = true

      subject.ReadOrProposeIfNeeded
    end

    it "does nothing if already proposed" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to_not receive(:Read)
      Yast::BootCommon.was_proposed = true

      subject.ReadOrProposeIfNeeded
    end

    it "does nothing in config mode" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to_not receive(:Read)
      expect(Yast::Mode).to receive(:config).and_return(true)

      subject.ReadOrProposeIfNeeded
    end

    it "propose configuration in initial stage except update mode" do
      expect(subject).to receive(:Propose)
      expect(subject).to_not receive(:Read)
      expect(Yast::Stage).to receive(:initial).and_return(true)
      expect(Yast::Mode).to receive(:update).and_return(false)

      subject.ReadOrProposeIfNeeded
    end

    it "reads configuration in normal stage" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to receive(:Read)
      expect(Yast::Stage).to receive(:initial).and_return(false)
      allow(Yast::Mode).to receive(:update).and_return(false)

      subject.ReadOrProposeIfNeeded
    end

    it "reads configuration in update mode" do
      expect(subject).to_not receive(:Propose)
      expect(subject).to receive(:Read)
      expect(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::Mode).to receive(:update).and_return(true)
      allow(subject).to receive(:UpdateConfiguration)

      subject.ReadOrProposeIfNeeded
    end

    it "calls .UpdateConfiguration in update mode" do
      allow(Yast::Stage).to receive(:initial).and_return(true)
      allow(Yast::Mode).to receive(:update).and_return(true)
      expect(subject).to receive(:UpdateConfiguration)

      subject.ReadOrProposeIfNeeded
    end
  end
end
