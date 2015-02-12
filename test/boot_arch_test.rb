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
end
