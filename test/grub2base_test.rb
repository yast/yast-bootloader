require_relative "test_helper"

require "bootloader/grub2base"

describe Bootloader::Grub2Base do
  describe "#read" do
    before do
      allow(::CFA::Grub2::Default).to receive(:new).and_return(double("GrubDefault", loaded?: false, load: nil, save: nil))
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(double("GrubCfg", load: nil))
      allow(Bootloader::Sections).to receive(:new).and_return(double("Sections", write: nil))
    end

    it "reads grub default config" do
      grub_default = double(::CFA::Grub2::Default, loaded?: false)
      allow(::CFA::Grub2::Default).to receive(:new).and_return(grub_default)

      expect(grub_default).to receive(:load)

      subject.read
    end

    it "reads sections from grub.cfg file" do
      grub_cfg = double(::CFA::Grub2::GrubCfg, load: nil)
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(grub_cfg)

      expect(Bootloader::Sections).to receive(:new).with(grub_cfg)

      subject.read
    end
  end

  describe "write" do
    before do
      allow(::CFA::Grub2::Default).to receive(:new).and_return(double("GrubDefault", loaded?: false, load: nil, save: nil))
      allow(::CFA::Grub2::GrubCfg).to receive(:new).and_return(double("GrubCfg", load: nil))
      allow(Bootloader::Sections).to receive(:new).and_return(double("Sections", write: nil))
    end

    it "stores grub default config" do
      grub_default = double(::CFA::Grub2::Default, loaded?: false)
      expect(::CFA::Grub2::Default).to receive(:new).and_return(grub_default)

      expect(grub_default).to receive(:save)
      # cannot be in before section is created in constructor
      subject.define_singleton_method(:name) { "grub2base" }

      subject.write
    end

    it "stores chosen default section" do
      sections = double("Sections")
      expect(Bootloader::Sections).to receive(:new).and_return(sections)
      subject.define_singleton_method(:name) { "grub2base" }

      expect(sections).to receive(:write)

      subject.write
    end
  end

  describe "#propose" do
    before do
      allow(Yast::BootStorage).to receive(:available_swap_partitions).and_return([])
    end

    describe "os_prober proposal" do
      before do
        allow(Yast::ProductFeatures).to receive(:GetBooleanFeature).and_return(false)
        allow(Yast::Arch).to receive(:architecture).and_return("x86_64")
      end

      context "on s390" do
        before do
          allow(Yast::Arch).to receive(:architecture).and_return("s390_64")
        end

        it "disable os probing" do
          subject.propose

          expect(subject.grub_default.os_prober.enabled?).to eq false
        end
      end
    end
  end
end
