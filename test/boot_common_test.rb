require_relative "test_helper"

Yast.import "BootCommon"

describe Yast::BootCommon do
  describe ".setKernelParamToLine" do
    def expect_set(key: nil, val: nil, old: nil, new: nil)
      expect(Yast::BootCommon.setKernelParamToLine(old, key, val))
        .to eq new
    end

    it "return line with added key=value if there is not yet such key on line" do
      expect_set(key: "vga",
                 val: "800",
                 old: "quit silent=1",
                 new: "quit silent=1 vga=800")
    end

    it "return line with modified kernel parameter to given value if line contain key" do
      expect_set(key: "vga",
                 val: "800",
                 old: "quit silent=1 vga=753",
                 new: "quit silent=1 vga=800")
    end

    context "when kernel parameter is duplicated" do
      it "return line with modified kernel parameter to given value avoiding duplications" do
        expect_set(key: "crashkernel",
                   val: "64M,low",
                   old: "quit silent=1 crashkernel=128M,low crashkernel=256M,high",
                   new: "quit silent=1 crashkernel=64M,low")
      end
    end

    context "when value is an array" do
      it "return line with modified kernel parameter to given values if line contain key" do
        expect_set(key: "crashkernel",
                   val: ["128M,low", "256M,high"],
                   old: "quit silent=1",
                   new: "quit silent=1 crashkernel=128M,low crashkernel=256M,high")
      end
    end

    it "return line with added parameter to kernel parameter line if value is \"true\"" do
      expect_set(key: "verbose",
                 val: "true",
                 old: "quit silent=1 vga=753",
                 new: "quit silent=1 vga=753 verbose")
    end

    it "return same line if parameter is already on parameter line when value is \"true\"" do
      expect_set(key: "quit",
                 val: "true",
                 old: "quit silent=1 vga=753",
                 new: "quit silent=1 vga=753")
    end

    it "return line with removed parameter from line if value is \"false\"" do
      expect_set(key: "quit",
                 val: "false",
                 old: "quit silent=1 vga=753",
                 new: "silent=1 vga=753")
    end

    it "return same line if parameter is already missing on line when value is \"false\"" do
      expect_set(key: "verbose",
                 val: "false",
                 old: "quit silent=1 vga=753",
                 new: "quit silent=1 vga=753")
    end

    it "return line with key=value if line is nil" do
      expect_set(key: "silent",
                 val: "1",
                 old: nil,
                 new: "silent=1")
    end

    it "return line with key when value is \"true\" and line is nil" do
      expect_set(key: "verbose",
                 val: "true",
                 old: nil,
                 new: "verbose")
    end

    it "return quoted empty string when value is \"false\" and line is nil" do
      expect_set(key: "verbose",
                 val: "false",
                 old: nil,
                 new: '""')
    end
  end

  describe ".getKernelParamFromLine" do
    context "when parameter is not defined" do
      let(:line) { "quiet" }

      it "returns 'false'" do
        expect(Yast::BootCommon.getKernelParamFromLine("quiet", "crashkernel")).to eq("false")
      end
    end

    context "when parameter is present but hasn't got a value" do
      let(:line) { "quiet" }

      it "returns 'true'" do
        expect(Yast::BootCommon.getKernelParamFromLine(line, "quiet")).to eq("true")
      end

      context "and is duplicated" do
        let(:line) { "quiet crashkernel=72M,low quiet" }

        it "returns the value" do
          expect(Yast::BootCommon.getKernelParamFromLine(line, "quiet")).to eq("true")
        end
      end
    end

    context "when parameter has a value" do
      let(:line) { "quiet crashkernel=72M,low" }

      it "returns the value" do
        expect(Yast::BootCommon.getKernelParamFromLine(line, "crashkernel"))
          .to eq("72M,low")
      end
    end

    context "when parameter has many values" do
      let(:line) { "quiet crashkernel=72M,low crashkernel=128M,high" }

      it "returns all the values as an array" do
        expect(Yast::BootCommon.getKernelParamFromLine(line, "crashkernel"))
          .to eq(["72M,low", "128M,high"])
      end
    end
  end

end
