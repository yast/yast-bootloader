# frozen_string_literal: true

require "yast"

Yast.import "Package"
Yast.import "Arch"

module Bootloader
  # Helper methods for the os-prober package
  class OsProber
    class << self
      def package_name
        "os-prober"
      end

      # Check if os-prober is supported on this architecture
      # no grub2-bls bootloader and if the package is available
      def available?(bootloader)
        arch_supported? && package_available? && bootloader != "grub2-bls"
      end

      # Check if the os-prober package is available for installation
      def package_available?
        Yast::Package.Available(package_name)
      end

      # Check if os-prober is supported on this architecture
      def arch_supported?
        !Yast::Arch.s390
      end
    end
  end
end
