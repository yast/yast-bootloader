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
      raise "cannot have secure boot without efi" if secure_boot && !efi
      raise "cannot have trusted boot with efi" if trusted_boot && efi

# storage-ng
# no need for this, 'pbl' reads the settings from sysconfig and runs grub2-install
=begin
      cmd = basic_cmd(secure_boot, trusted_boot)

      if no_device_install?
        Yast::Execute.on_target(cmd)
      else
        devices.each { |d| Yast::Execute.on_target(cmd + [d]) }
      end
=end

      # '--force' is needed as 'pbl' refuses to run during install
      Yast::Execute.on_target(["/sbin/pbl", "--install", "--force"])
    end

  private

    attr_reader :efi

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
      efi && Dir.glob("/sys/firmware/efi/efivars/*").empty?
    end

    def no_device_install?
      Yast::Arch.s390 || efi
    end

    NON_EFI_TARGETS = {
      "i386"    => "i386-pc",
      "x86_64"  => "i386-pc", # x64 use same legacy boot for backward compatibility
      "s390_32" => "s390x-emu",
      "s390_64" => "s390x-emu",
      "ppc"     => "powerpc-ieee1275",
      "ppc64"   => "powerpc-ieee1275"
    }.freeze

    EFI_TARGETS = {
      "i386"    => "i386-efi",
      "x86_64"  => "x86_64-efi",
      "arm"     => "arm-efi",
      "aarch64" => "arm64-efi"
    }.freeze
    def target
      return @target if @target

      arch = Yast::Arch.architecture
      target = efi ? EFI_TARGETS[arch] : NON_EFI_TARGETS[arch]

      if !target
        raise "unsupported combination of architecture #{arch} and " \
          "#{efi ? "enabled" : "disabled"} EFI"
      end

      @target ||= target
    end
  end
end
