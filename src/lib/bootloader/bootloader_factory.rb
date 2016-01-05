require "yast"
require "yast/"
require "bootloader/sysconfig"

Yast.import "Arch"
Yast.import "Mode"
Yast.import "Linuxrc"

module Bootloader
  # Factory to get instance of bootloader
  class BootloaderFactory
    class << self
      SUPPORTED_BOOTLOADERS = [
        "none", # allows user to manage bootloader itself
        "grub2",
        "grub2-efi"
      ]

      def proposed
        bootloader_by_name(proposed_name)
      end

      def system
        bootloader_by_name(Sysconfig.from_system.bootloader)
      end

      def supported_names
        if Yast::Mode.config
          # default means bootloader use what it think is the best
          return SUPPORTED_BOOTLOADERS + ["default"]
        end

        ret = []
        system_bl = system.name rescue nil # rescue exception if system one is not support
        system_bl = system_bl ? [system.name] : [] # use current as first
        ret << "grub2" unless Yast::Arch.aarch64 # grub2 everywhere except aarch64
        ret << "grub2-efi" if Yast::Arch.x86_64 || Yast::Arch.aarch64
        ret << "none"
        # avoid double entry for selected one
        ret.uniq
      end

      def bootloader_by_name(name)
        case name
        when "grub2"
          Yast::BootGRUB2 # replace by instance in future
        when "grub2-efi"
          Yast::BootGRUB2EFI
        when "none"
          # TODO own class
        else
          # TODO exception for unsupported bootloader
        end
      end

    private
      def boot_efi?
        if Yast::Mode.live_installation
           Yast::Execute.locally("modprobe", "efivars")
           ::File.exist?("/sys/firmware/efi/systab")
        else
          Yast::Linuxrc.InstallInf("EFI") == "1"
        end
      end

      def proposed_name
        return "grub2-efi" if Yast::Arch.aarch64

        if Yast::Arch.x86_64 && boot_efi?
          return "grub2-efi"
        end

        "grub2" # grub2 works(c) everywhere
      end
    end
  end
end
