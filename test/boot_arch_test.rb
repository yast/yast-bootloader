require_relative "test_helper"

Yast.import "BootArch"

describe Yast::BootArch do
  subject { Yast::BootArch }

  def stub_arch(arch)
    Yast.import "Arch"

    allow(Yast::Arch).to receive(:architecture).and_return(arch)
  end

  describe ".VgaAvailable" do
    it "returns true if it is on x86_64 architecture" do
      stub_arch("x86_64")

      expect(subject.VgaAvailable).to eq true
    end

    it "returns true if it is on i386 architecture" do
      stub_arch("i386")

      expect(subject.VgaAvailable).to eq true
    end

    it "otherwise it returns false" do
      stub_arch("s390x")

      expect(subject.VgaAvailable).to eq false
    end
  end

  describe ".ResumeAvailable" do
    it "returns true if it is on x86_64 architecture" do
      stub_arch("x86_64")

      expect(subject.ResumeAvailable).to eq true
    end

    it "returns true if it is on i386 architecture" do
      stub_arch("i386")

      expect(subject.ResumeAvailable).to eq true
    end

    it "returns true if it is on s390 architecture" do
      stub_arch("s390_64")

      expect(subject.ResumeAvailable).to eq true
    end

    it "otherwise it returns false" do
      stub_arch("ppc64")

      expect(subject.ResumeAvailable).to eq false
    end
  end

  describe ".DefaultKernelParams" do
    context "on x86_64 or i386" do
      before do
        stub_arch("x86_64")
      end

      it "adds parameters from boot command line" do
        allow(Yast::Kernel).to receive(:GetCmdLine).and_return("console=ttyS0")

        expect(subject.DefaultKernelParams("/dev/sda2")).to include("console=ttyS0")
      end

      it "adds additional parameters from Product file" do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return("console=ttyS0")

        expect(subject.DefaultKernelParams("/dev/sda2")).to include("console=ttyS0")
      end

      it "removes splash param from command line or product file and add it silent" do
        allow(Yast::Kernel).to receive(:GetCmdLine).and_return("splash=verbose")

        expect(subject.DefaultKernelParams("/dev/sda2")).to include("splash=silent")
        expect(subject.DefaultKernelParams("/dev/sda2")).to_not include("splash=verbose")
      end

      it "adds passed parameter as resume device" do
        expect(subject.DefaultKernelParams("/dev/sda2")).to include("resume=/dev/sda2")
      end

      it "do not adds resume device if parameter is empty" do
        expect(subject.DefaultKernelParams("")).to_not include("resume")
      end

      it "adds splash=silent quit showopts parameters" do
        expect(subject.DefaultKernelParams("/dev/sda2")).to include(" splash=silent quiet showopts")
      end
    end

    context "on s390" do
      before do
        stub_arch("s390_64")
      end

      it "adds additional parameters from Product file" do
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).and_return("console=ttyS0")

        expect(subject.DefaultKernelParams("/dev/sda2")).to include("console=ttyS0")
      end
    end
  end
end
