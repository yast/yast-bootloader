require "yast"
require "bootloader/sysconfig"

Yast.import "BootStorage"
Yast.import "Linuxrc"
Yast.import "Mode"

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
      []
    end

    # rubocop:disable Style/TrivialAccessors
    # @return true if configuration is already read
    def read?
      @read
    end

    # rubocop:disable Style/TrivialAccessors
    # @return true if configuration is already proposed
    def proposed?
      @proposed
    end

    # list of packages needed for configure given bootloader
    def packages
      res = []

      # added kexec-tools fate# 303395
      if !Yast::Mode.live_installation &&
          Yast::Linuxrc.InstallInf("kexec_reboot") != "0"
        res << "kexec-tools"
      end

      res
    end

  protected

    def write_sysconfig
      sysconfig = Bootloader::Sysconfig.new(bootloader: name)
      sysconfig.write
    end
  end
end
