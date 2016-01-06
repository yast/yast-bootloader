require "yast"
require "bootloader/sysconfig"

Yast.import "BootStorage"

module Bootloader
  # Represents base for all kinds of bootloaders
  class BootloaderBase
    def write
      write_sysconfig
    end

    def read
      Yast::BootStorage.detect_disks
    end

  protected

    def write_sysconfig
      sysconfig = Bootloader::Sysconfig.new(bootloader: name)
      sysconfig.write
    end
  end
end
