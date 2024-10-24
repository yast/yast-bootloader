# frozen_string_literal: true

require "yast"
require "bootloader/sysconfig"
require "bootloader/none_bootloader"
require "bootloader/grub2"
require "bootloader/grub2efi"
require "bootloader/grub2bls"
require "bootloader/systemdboot"
require "bootloader/exceptions"

Yast.import "Arch"
Yast.import "Mode"
Yast.import "ProductFeatures"

module Bootloader
  # Factory to get instance of bootloader
  class BootloaderFactory
    SUPPORTED_BOOTLOADERS = [
      "none", # allows user to manage bootloader itself
      "grub2",
      "grub2-efi"
    ].freeze

    # Keyword used in autoyast for default bootloader used for given system.
    DEFAULT_KEYWORD = "default"
    SYSTEMDBOOT = "systemd-boot"
    GRUB2BLS = "grub2-bls"

    class << self
      include Yast::Logger

      attr_writer :current

      def proposed
        bootloader_by_name(proposed_name)
      end

      def system
        sysconfig_name = Sysconfig.from_system.bootloader
        return nil unless sysconfig_name

        bootloader_by_name(sysconfig_name)
      end

      def current
        @current ||= (system || proposed)
      end

      def current_name=(name)
        @current = bootloader_by_name(name)
      end

      def clear_cache
        @cached_bootloaders = nil
      end

      def supported_names
        if Yast::Mode.config
          # default means bootloader use what it think is the best
          result = BootloaderFactory::SUPPORTED_BOOTLOADERS.clone
          result << GRUB2BLS if use_grub2_bls?
          result << SYSTEMDBOOT if use_systemd_boot?
          result << DEFAULT_KEYWORD
          return result
        end

        begin
          system_bl = system.name
        # rescue exception if system one is not support
        rescue StandardError
          system_bl = nil
        end
        ret = system_bl ? [system.name] : [] # use current as first
        # grub2 everywhere except aarch64 or riscv64
        ret << "grub2" unless Systeminfo.efi_mandatory?
        ret << "grub2-efi" if Systeminfo.efi_supported?
        ret << GRUB2BLS if use_grub2_bls?
        ret << SYSTEMDBOOT if use_systemd_boot?
        ret << "none"
        # avoid double entry for selected one
        ret.uniq
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def bootloader_by_name(name)
        # needed to be able to store settings when moving between bootloaders
        @cached_bootloaders ||= {}
        case name
        when "grub2"
          @cached_bootloaders["grub2"] ||= Grub2.new
        when "grub2-efi"
          @cached_bootloaders["grub2-efi"] ||= Grub2EFI.new
        when "systemd-boot"
          @cached_bootloaders["systemd-boot"] ||= SystemdBoot.new
        when "grub2-bls"
          @cached_bootloaders["grub2-bls"] ||= Grub2Bls.new
        when "none"
          @cached_bootloaders["none"] ||= NoneBootloader.new
        when String
          raise UnsupportedBootloader, name
        else
          log.error "Factory receive nil name"

          nil # in other cases it means that read failed
        end
      end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

      def use_systemd_boot?
        Yast::ProductFeatures.GetBooleanFeature("globals", "enable_systemd_boot") &&
          (Yast::Arch.x86_64 || Yast::Arch.aarch64) # only these architectures are supported.
      end

      def use_grub2_bls?
        (Yast::Arch.x86_64 || Yast::Arch.aarch64) # only these architectures are supported.
      end

      def grub2_efi_installable?
        Systeminfo.efi_mandatory? ||
          ((Yast::Arch.x86_64 || Yast::Arch.i386) && Systeminfo.efi?)
      end

      def proposed_name
        prefered_bootloader = Yast::ProductFeatures.GetStringFeature("globals",
          "prefered_bootloader")
        if supported_names.include?(prefered_bootloader) && prefered_bootloader != "grub2-efi"
          return prefered_bootloader
        end

        return "grub2-efi" if grub2_efi_installable?

        "grub2" # grub2 works(c) everywhere
      end
    end
  end
end
