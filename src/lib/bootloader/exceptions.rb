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

  # universal exception when unrecoverable error found during parsing configuration
  # holds in {#reason} translated message what exactly is broken.
  class BrokenConfiguration < RuntimeError
    include Yast::I18n
    attr_reader :reason

    def initialize(msg)
      @reason = msg
      textdomain "bootloader"

      # TRANSLATORS: %s is translated description of error
      super _("Error reading the bootloader configuration files. " \
        "Please use YaST2 bootloader to fix it. Details: %s") % msg
    end
  end

  # Represent unsupported value in given option. Used mainly when value contain something that
  # bootloader does not understand yet.
  class UnsupportedOption < RuntimeError
    include Yast::I18n
    attr_reader :option

    def initialize(option)
      @reason = option
      textdomain "bootloader"

      # TRANSLATORS: %s is name of option that has unsupported value
      super _("Option '%s' contains an unrecognized value.\nYaST Bootloader cannot handle it.\n" \
        "Either the whole bootloader configuration needs to be proposed again\n" \
        "or YaST must quit and you can edit it manually.") % option
    end
  end

  # Represents error when serial console arguments are not valid
  class InvalidSerialConsoleArguments < BrokenConfiguration
    MESSAGE = "Invalid serial console arguments".freeze
    def initialize(msg = MESSAGE)
      super
    end
  end

  class NoRoot < RuntimeError
  end
end
