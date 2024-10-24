# frozen_string_literal: true

require "yast"
require "bootloader/grub2efi"

Yast.import "Arch"
Yast.import "Report"
Yast.import "Stage"
Yast.import "BootStorage"

module Bootloader
  # Represents grub2 bls bootloader with efi target
  class Grub2Bls < Grub2EFI
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

    def write(etc_only: false)
      super
      install_bootloader if Yast::Stage.initial # while new installation only (currently)
      create_menu_entries
      install_bootloader # not sure if needed again      
    end

    def packages
      res = super
      res << "grub2-" + Yast::Arch.architecture + "-efi-bls"
      res
    end

  private

    SDBOOTUTIL = "/usr/bin/sdbootutil"

    def create_menu_entries
      # writing kernel parameter to /etc/kernel/cmdline
      File.open(File.join(Yast::Installation.destdir, CMDLINE), "w+") do |fw|
        if Yast::Stage.initial # while new installation only
          fw.puts("root=#{Yast::BootStorage.root_partitions.first.name} #{kernel_params.serialize}")
        else # root entry is already available
          fw.puts(kernel_params.serialize)
        end
      end

      begin
        Yast::Execute.on_target!(SDBOOTUTIL, "--verbose", "add-all-kernels")
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot create systemd-boot menu entry:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
      end
    end
    
    def install_bootloader
      Yast::Execute.on_target!(SDBOOTUTIL, "--verbose",
        "install")
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
      format(_(
               "Cannot install systemd bootloader:\n" \
               "Command `%{command}`.\n" \
               "Error output: %{stderr}"
             ), command: e.commands.inspect, stderr: e.stderr)
    )
      nil
    end    

  end
end
