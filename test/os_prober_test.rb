# frozen_string_literal: true

require_relative "test_helper"

describe Bootloader::OsProber do
  subject = described_class

  describe "#package_name" do
    it "Returns the correct package name" do
      expect(subject.package_name).to eq "os-prober"
    end
  end

  describe "#arch_supported?" do
    context "on non-s390 architectures" do
      before do
        allow(Yast::Arch).to receive(:s390).and_return(false)
      end

      it "os-prober is supported" do
        expect(subject.arch_supported?).to eq true
      end
    end

    context "on the s390 architecture" do
      before do
        allow(Yast::Arch).to receive(:s390).and_return(true)
      end

      it "os-prober is not supported" do
        expect(subject.arch_supported?).to eq false
      end
    end
  end

  describe "#available?" do
    context "on non-s390 architectures" do
      before do
        allow(Yast::Arch).to receive(:s390).and_return(false)
      end

      context "if the os-prober package is available" do
        before do
          allow(Yast::Package).to receive(:Available).and_return(true)
        end

        it "os-prober is available" do
          expect(subject.available?).to eq true
        end
      end

      context "if the os-prober package is not available" do
        before do
          allow(Yast::Package).to receive(:Available).and_return(false)
        end

        it "os-prober is not available" do
          expect(subject.available?).to eq false
        end
      end
    end
  end
end
