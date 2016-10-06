require "yast"

module Bootloader
  # Represents error when during read it found bootloader name that is not supported.
  class UnsupportedBootloader < RuntimeError
    attr_reader :bootloader_name
    def initialize(bootloader_name)
      super "Uninitialized bootlader '#{bootloader_name}'"
      @bootloader_name = bootloader_name
    end
  end

  class BrokenConfiguration < RuntimeError
    include Yast::I18n
    attr_reader :reason

    def initialize(msg)
      @reason = msg
      textdomain "bootloader"

      super _("Found problem during reading bootloader configuration files. " \
        "Please open bootloader module and fix it. Details: %s") % msg
    end
  end
end
