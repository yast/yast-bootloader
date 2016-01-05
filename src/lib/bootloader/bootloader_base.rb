require "bootloader/sysconfig"

module Bootloader
  class BootloaderBase
    def write
      write_sysconfig
    end

    def read
    end

  protected
    def write_sysconfig
      sysconfig = Bootloader::Sysconfig.new(bootloader: name)
      sysconfig.write
    end
  end
end
