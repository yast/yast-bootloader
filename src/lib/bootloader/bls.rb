# frozen_string_literal: true

require "fileutils"
require "yast"
require "y2storage"
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
      Yast::Execute.on_target!(SDBOOTUTIL,  "add-all-kernels")
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
      Yast::Execute.on_target!(SDBOOTUTIL, "install")
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
      Yast::Execute.on_target!(SDBOOTUTIL, "set-timeout", timeout)
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
        output = -1
      end
      output
    end

    def self.write_default_menu(default)
      return if default.empty?
      begin
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
      output.strip!
    end


    # Enabe TPM2, if it is required
    def self.enable_tpm2
      return unless Y2Storage::StorageManager.instance.encryption_use_tpm2

      begin
        Yast::Execute.on_target!("keyctl", "padd", "user", "cryptenroll",
           "@u", stdout: :capture,
           stdin: Y2Storage::StorageManager.instance.proposal.settings.encryption_password)
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot pass the password via the keyring:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
        return
      end

      Yast::SCR.Execute(Yast::Path.new(".target.remove"), "/etc/machine-id")
      begin
        Yast::Execute.on_target!("/usr/bin/dbus-uuidgen",
                                 "--ensure=/etc/machine-id")

      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot Cannot create machine-id:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
      end
      
      begin
        Yast::Execute.on_target!("/usr/bin/sdbootutil",
                                 "enroll", "--method=tpm2")
      rescue Cheetah::ExecutionFailed => e
        Yast::Report.Error(
          format(_(
                   "Cannot enroll TPM2 method:\n" \
                   "Command `%{command}`.\n" \
                   "Error output: %{stderr}"
                 ), command: e.commands.inspect, stderr: e.stderr)
        )
      end
    end
  end
end
