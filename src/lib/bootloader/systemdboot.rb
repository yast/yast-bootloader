# frozen_string_literal: true

require "fileutils"
require "yast"
require "cfa/systemd_boot"

Yast.import "Report"
Yast.import "Arch"
Yast.import "ProductFeatures"
Yast.import "BootStorage"
Yast.import "Stage"

module Bootloader
  # Represents systemd bootloader with efi target
  class SystemdBoot < BlsBootloader
    include Yast::Logger
    include Yast::I18n

    # @!attribute menu_timeout
    #   @return [Integer] menu timeout
    attr_accessor :menu_timeout

    def merge(other)
      super
      
      log.info "merging: timeout: #{menu_timeout}=>#{other.menu_timeout}"
      self.menu_timeout = other.menu_timeout unless other.menu_timeout.nil?
      log.info "merging result: timeout: #{menu_timeout}"
    end

    def read
      super

      read_menu_timeout
    end

    # Write bootloader settings to disk
    def write(etc_only: false)
      super
      write_menu_timeout

      true
    end

    def propose
      super

      self.menu_timeout = Yast::ProductFeatures.GetIntegerFeature("globals", "boot_timeout").to_i
    end

    # Display bootloader summary
    # @return a list of summary lines
    def summary(*)
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "Systemd Boot"
        )
      ]
      result << super
      result
    end

    def name
      "systemd-boot"
    end

    def packages
      res = super
      res << "systemd-boot"
      res
    end

  private

    def read_menu_timeout
      config = CFA::SystemdBoot.load
      return unless config.menu_timeout

      self.menu_timeout = if config.menu_timeout == "menu-force"
        -1
      else
        config.menu_timeout.to_i
      end
    end

    def write_menu_timeout
      config = CFA::SystemdBoot.load
      config.menu_timeout = if menu_timeout == -1
        "menu-force"
      else
        menu_timeout.to_s
      end
      config.save
    end

  end
end
