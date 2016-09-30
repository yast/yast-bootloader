module Bootloader
  class UnsupportedBootloader < RuntimeError
    attr_reader :bootloader_name
    def initialize(bootloader_name)
      super "Uninitialized bootlader '#{bootloader_name}'"
      @bootloader_name = bootloader_name
    end
  end
end
