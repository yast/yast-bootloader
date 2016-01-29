require "yast"
require "bootloader/sysconfig"

Yast.import "BootStorage"

module Bootloader
  # Represents base for all kinds of bootloaders
  class BootloaderBase
    def initialize
      @read = false
      @proposed = false
    end

    # writes configuration to target disk
    def write
      write_sysconfig
    end

    # reads configuration from target disk
    def read
      Yast::BootStorage.detect_disks
      @read = true
    end

    # Proposes new configuration
    def propose
      @proposed = true
    end

    # @return [Array<String>] description for proposal summary page for given bootloader
    def summary
    end

    def read?
      @read
    end

    def proposed?
      @proposed
    end

  protected

    def write_sysconfig
      sysconfig = Bootloader::Sysconfig.new(bootloader: name)
      sysconfig.write
    end
  end
end
