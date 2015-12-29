require "yast"
require "yast2/execute"

Yast.import "Arch"

module Bootloader
  class GrubInstall
    def initialize(efi: false, secure_boot: false)
      @efi = efi
      @secure_boot = secure_boot

      raise "cannot have secure boot without efi" if secure_boot && !efi
    end

    def execute(devices: nil)
      cmd = []
      if @secure_boot
        cmd << "/usr/sbin/shim-install" << "--config-file=/boot/grub2/grub.cfg"
      else
        cmd << "/usr/sbin/grub2-install" << "--target=#{target}"
        # Do skip-fs-probe to avoid error when embedding stage1
        # to extended partition
        cmd << "--force" << "--skip-fs-probe"
      end

      if devices
        devices.each do |dev|
          Yast::Execute.locally(cmd + [dev])
        end
      else
        Yast::Execute.locally cmd
      end
    end

  private

    def target
      @target ||= case Yast::Arch.architecture
      when "i386"
        if @efi
          "i386-efi"
        else
          "i386-pc"
        end
      when "x86_64"
        if @efi
          "x86_64-efi"
        else
          "i386-pc"
        end
      when "ppc", "ppc64"
        raise "EFI on ppc not supported" if @efi
        "powerpc-ieee1275"
      when "s390_32", "s390_64"
        raise "EFI on s390 not supported" if @efi
        "s390x-emu"
      when "aarch64"
        raise "Only EFI supported on aarch64" unless @efi
        "arm64-efi"
      else
        raise "unsupported architecture '#{Yast::Arch.architecture}'"
      end
    end
  end
end
