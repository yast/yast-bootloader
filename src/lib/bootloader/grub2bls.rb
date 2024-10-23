# frozen_string_literal: true

require "yast"
require "bootloader/bls_boot"

Yast.import "Arch"

module Bootloader
  # Represents grub2 bls bootloader with efi target
  class Grub2BlsBoot < BlsBootloader
    include Yast::Logger
    include Yast::I18n

    # Display bootloader summary
    # @return a list of summary lines
    def summary(*)
      result = [
        Yast::Builtins.sformat(
          _("Boot Loader Type: %1"),
          "GRUB2 BLS"
        )
      ]
      result << super
      result
    end

    def name
      "grub2-bls"
    end

    def packages
      res = super
      res << "grub2-" + Yast::Arch.architecture + "-efi-bls"
      res
    end

  end
end
