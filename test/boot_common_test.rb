require_relative "test_helper"

Yast.import "BootCommon"

describe Yast::BootCommon do
  describe ".setKernelParamToLine" do
    it "return line with added key=value if there is not yet such key on line" do
      line = "quit silent=1"
      result_line = "quit silent=1 vga=800"
      expect(Yast::BootCommon.setKernelParamToLine(
        line, "vga", "800")).to eq result_line
    end

    it "return line with modified kernel parameter to given value if line contain key" do
      line = "quit silent=1 vga=753"
      result_line = "quit silent=1 vga=800"
      expect(Yast::BootCommon.setKernelParamToLine(
        line, "vga", "800")).to eq result_line
    end

    it "return line with added parameter to kernel parameter line if value is \"true\"" do
      line = "quit silent=1 vga=753"
      result_line = "quit silent=1 vga=753 verbose"
      expect(Yast::BootCommon.setKernelParamToLine(
        line, "verbose", "true")).to eq result_line
    end

    it "return same line if parameter is already on parameter line when value is \"true\"" do
      line = "quit silent=1 vga=753"
      result_line = "quit silent=1 vga=753"
      expect(Yast::BootCommon.setKernelParamToLine(
        line, "quit", "true")).to eq result_line
    end

    it "return line with removed parameter from line if value is \"false\"" do
      line = "quit silent=1 vga=753"
      result_line = "silent=1 vga=753"
      expect(Yast::BootCommon.setKernelParamToLine(
        line, "quit", "false")).to eq result_line
    end

    it "return same line if parameter is already missing on line when value is \"false\"" do
      line = "quit silent=1 vga=753"
      result_line = "quit silent=1 vga=753"
      expect(Yast::BootCommon.setKernelParamToLine(
        line, "verbose", "false")).to eq result_line
    end
  end
end
