require "yast"
require "yast2/execute"

Yast.import "Arch"

module Bootloader
  # Wraps grub install script for easier usage.
  class GrubInstall
    def initialize(efi: false)
      @efi = efi
    end

    def execute(devices: [], secure_boot: false, trusted_boot: false)
      raise "cannot have secure boot without efi" if secure_boot && !@efi
      raise "cannot have trusted boot with efi" if trusted_boot && @efi

      cmd = basic_cmd(secure_boot, trusted_boot)

      if no_device_install?
        Yast::Execute.on_target(cmd)
      else
        devices.each { |d| Yast::Execute.on_target(cmd + [d]) }
      end
    end

  private

    # creates basic command for grub2 install without specifying any stage1
    # locations
    def basic_cmd(secure_boot, trusted_boot)
      if secure_boot
        cmd = ["/usr/sbin/shim-install", "--config-file=/boot/grub2/grub.cfg"]
      else
        cmd = ["/usr/sbin/grub2-install", "--target=#{target}"]
        # Do skip-fs-probe to avoid error when embedding stage1
        # to extended partition
        cmd << "--force" << "--skip-fs-probe"
        cmd << "--directory=/usr/lib/trustedgrub2/#{target}" if trusted_boot
      end

      cmd << "--no-nvram" << "--removable" if removable_efi?

      cmd
    end

    def removable_efi?
      # EFI has 2 boot paths. The default is that there is a target file listed
      # in the boot list. The boot list is stored in NVRAM and exposed as
      # efivars.
      #
      # If no entry in the boot list was bootable (or a removable media is in
      # the boot list), EFI falls back to removable media booting which loads
      # a default file from /efi/boot/boot.efi.
      #
      # On U-Boot EFI capable systems we do not have NVRAM because we would
      # have to store that on the same flash that Linux may be running on,
      # creating device ownership conflicts. So on those systems we instead have
      # to rely on the removable boot case.
      #
      # The easiest heuristic is that on "normal" EFI systems with working
      # NVRAM, there is at least one efi variable visible. On systems without
      # working NVRAM, we either see no efivars at all (booted via non-EFI entry
      # point) or there is no efi variable exposed. Install grub in the
      # removable location there.
      @efi && Dir.glob("/sys/firmware/efi/efivars/*").empty?
    end

    def no_device_install?
      Yast::Arch.s390 || @efi
    end

    def target
      @target ||= case Yast::Arch.architecture
                  when "i386"               then i386_target
                  when "x86_64"             then x64_target
                  when "ppc", "ppc64"       then ppc_target
                  when "s390_32", "s390_64" then s390_target
                  when "aarch64"            then aarch64_target
                  else
                    raise "unsupported architecture '#{Yast::Arch.architecture}'"
                  end
    end

    def i386_target
      if @efi
        "i386-efi"
      else
        "i386-pc"
      end
    end

    def x64_target
      if @efi
        "x86_64-efi"
      else
        "i386-pc"
      end
    end

    def ppc_target
      raise "EFI on ppc not supported" if @efi

      "powerpc-ieee1275"
    end

    def s390_target
      raise "EFI on s390 not supported" if @efi

      "s390x-emu"
    end

    def aarch64_target
      raise "Only EFI supported on aarch64" unless @efi

      "arm64-efi"
    end
  end
end
