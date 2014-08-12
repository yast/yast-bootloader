require_relative "test_helper"

Yast.import "BootCommon"

describe Yast::BootCommon do
  describe ".setKernelParamToLine" do
    it "return line with added key=value if there is not yet such key on line" do
      old_line = "quit silent=1"
      new_line = "quit silent=1 vga=800"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "vga", "800")).
        to eq new_line
    end

    it "return line with modified kernel parameter to given value if line contain key" do
      old_line = "quit silent=1 vga=753"
      new_line = "quit silent=1 vga=800"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "vga", "800")).
        to eq new_line
    end

    it "return line with added parameter to kernel parameter line if value is \"true\"" do
      old_line = "quit silent=1 vga=753"
      new_line = "quit silent=1 vga=753 verbose"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "verbose", "true")).
        to eq new_line
    end

    it "return same line if parameter is already on parameter line when value is \"true\"" do
      old_line = "quit silent=1 vga=753"
      new_line = "quit silent=1 vga=753"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "quit", "true")).
        to eq new_line
    end

    it "return line with removed parameter from line if value is \"false\"" do
      old_line = "quit silent=1 vga=753"
      new_line = "silent=1 vga=753"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "quit", "false")).
        to eq new_line
    end

    it "return same line if parameter is already missing on line when value is \"false\"" do
      old_line = "quit silent=1 vga=753"
      new_line = "quit silent=1 vga=753"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "verbose", "false")).
        to eq new_line
    end

    it "return line with key=value if line is nil" do
      old_line = nil
      new_line = "silent=1"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "silent", "1")).
        to eq new_line
    end

    it "return line with key when value is \"true\" and line is nil" do
      old_line = nil
      new_line = "verbose"
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "verbose", "true")).
        to eq new_line
    end

    it "return empty string when value is \"false\" and line is nil" do
      old_line = nil
      new_line = ""
      expect(Yast::BootCommon.setKernelParamToLine(old_line, "verbose", "false")).
        to eq new_line
    end
  end
end
