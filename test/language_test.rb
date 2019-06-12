# typed: ignore
require_relative "test_helper"

require "bootloader/language"
require "cfa/memory_file"

describe Bootloader::Language do
  describe "rc_lang" do
    it "returns value from parsed tree" do
      path = File.expand_path("../data/language", __FILE__)
      file = CFA::MemoryFile.new(File.read(path))

      language = described_class.new(file_handler: file)
      language.load

      expect(language.rc_lang).to eq "en_US.UTF-8"
    end

    it "returns nil if value missing in parsed tree" do
      file = CFA::MemoryFile.new("")

      language = described_class.new(file_handler: file)
      language.load

      expect(language.rc_lang).to eq nil
    end
  end
end
