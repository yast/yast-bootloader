# frozen_string_literal: true

require "yast"
require "y2storage"

Yast.import "Arch"
Yast.import "BootStorage"

module Bootloader
  # Helper methods for PMBR
  class Pmbr
    class << self
      include Yast::Logger

      def available?
        (Yast::Arch.x86_64 || Yast::Arch.i386) &&
          Yast::BootStorage.gpt_boot_disk?
      end

      def write(action, boot_loader)
        if ["grub2-efi", "grub2-bls", "systemd-boot"].include?(boot_loader)
          write_efi(action)
        else # grub2
          write_none_efi(action)
        end
      end

    private

      # Filesystems in the staging (planned) devicegraph
      #
      # @return [Y2Storage::FilesystemsList]
      def filesystems
        staging = Y2Storage::StorageManager.instance.staging
        staging.filesystems
      end

      def write_none_efi(action)
        stage1 = Stage1.new
        begin
          stage1.read
        rescue Errno::ENOENT
          # grub_installdevice is not part of grub2 rpm, so it doesn't need to exist.
          # In such case ignore exception and use empty stage1
          log.info "grub_installdevice does not exist. Using empty one."
          stage1 = Stage1.new
        end
        pmbr_setup(*::Yast::BootStorage.gpt_disks(stage1.devices), action)
      end

      def write_efi(action)
        fs = filesystems
        efi_partition = fs.find { |f| f.mount_path == "/boot/efi" }
        efi_partition ||= fs.find { |f| f.mount_path == "/boot" }
        efi_partition ||= fs.find { |f| f.mount_path == "/" }

        raise "could not find boot partiton" unless efi_partition

        disks = Yast::BootStorage.stage1_disks_for(efi_partition)
        # set only gpt disks
        disks.select! { |disk| disk.gpt? }
        pmbr_setup(*disks.map(&:name), action)
      end

      # set pmbr flags on boot disks
      def pmbr_setup(*devices, action)
        return if action == :nothing

        action_parted = case action
        when :add    then "on"
        when :remove then "off"
        else raise "invalid action #{action}"
        end

        devices.each do |dev|
          Yast::Execute.locally("/usr/sbin/parted", "-s", dev, "disk_set", "pmbr_boot",
            action_parted)
        end
      end
    end
  end
end
