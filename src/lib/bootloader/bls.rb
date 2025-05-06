# frozen_string_literal: true

require "fileutils"
require "yast"
require "bootloader/sysconfig"
require "bootloader/cpu_mitigations"
require "cfa/grub2/default"

Yast.import "Report"

module Bootloader
  # Represents bls compatile system calls which can be used
  # e.g. by grub2-bls and systemd-boot
  class Bls
    include Yast::Logger
    extend Yast::I18n

    SDBOOTUTIL = "/usr/bin/sdbootutil"

    def initialize
      textdomain "bootloader"
    end

    def self.create_menu_entries
      Yast::Execute.on_target!(SDBOOTUTIL, "--verbose", "add-all-kernels")
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
        format(_(
                 "Cannot create boot menu entry:\n" \
                 "Command `%{command}`.\n" \
                 "Error output: %{stderr}"
               ), command: e.commands.inspect, stderr: e.stderr)
      )
    end

    def self.install_bootloader
      Yast::Execute.on_target!(SDBOOTUTIL, "--verbose",
        "install")
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
      format(_(
               "Cannot install bootloader:\n" \
               "Command `%{command}`.\n" \
               "Error output: %{stderr}"
             ), command: e.commands.inspect, stderr: e.stderr)
    )
    end

    def self.write_menu_timeout(timeout)
      Yast::Execute.on_target!(SDBOOTUTIL, "set-timeout", "--", timeout)
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
      format(_(
               "Cannot write boot menu timeout:\n" \
               "Command `%{command}`.\n" \
               "Error output: %{stderr}"
             ), command: e.commands.inspect, stderr: e.stderr)
    )
    end

    def self.menu_timeout
      begin
        output = Yast::Execute.on_target!(SDBOOTUTIL, "get-timeout", stdout: :capture).to_i
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot read boot menu timeout:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
        output = -2 # -1 will be returned from sdbootutil for menu-force
      end
      output
    end

    def self.write_default_menu(default)
      Yast::Execute.on_target!(SDBOOTUTIL, "set-default", default)
    rescue Cheetah::ExecutionFailed => e
      Yast::Report.Error(
      format(_(
               "Cannot write default boot menu entry:\n" \
               "Command `%{command}`.\n" \
               "Error output: %{stderr}"
             ), command: e.commands.inspect, stderr: e.stderr)
    )
    end

    def self.default_menu
      begin
        output = Yast::Execute.on_target!(SDBOOTUTIL, "get-default", stdout: :capture)
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot read default menu:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
        output = ""
      end
      output
    end
  end
end
