require_relative "test_helper"

Yast.import "BootCommon"

describe Yast::BootCommon do
  describe ".setKernelParamToLine" do
    def expect_set(key: nil, val: nil, old: nil, new: nil)
      expect(Yast::BootCommon.setKernelParamToLine(old, key, val)).
        to eq new
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

    it "return empty string when value is \"false\" and line is nil" do
      expect_set(key: "verbose",
                 val: "false",
                 old: nil,
                 new: "")
    end
  end
end
