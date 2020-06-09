# frozen_string_literal: true

# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "installation/autoinst_profile/section_with_attributes"

module Bootloader
  module AutoinstProfile
    # This class represents an AutoYaST <global> section within a <bootloader> one
    class GlobalSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :activate },
          { name: :append },
          { name: :boot_boot },
          { name: :boot_custom },
          { name: :boot_extended },
          { name: :boot_mbr },
          { name: :boot_root },
          { name: :cpu_mitigations },
          { name: :generic_mbr },
          { name: :gfxmode },
          { name: :hiddenmenu },
          { name: :os_prober },
          { name: :secure_boot },
          { name: :serial },
          { name: :terminal },
          { name: :timeout },
          { name: :trusted_boot },
          { name: :trusted_grub },
          { name: :vgamode },
          { name: :xen_append },
          { name: :xen_kernel_append }
        ]
      end

      define_attr_accessors

      # @!attribute activate
      #   @return [Boolean,nil] whether to set the _boot_ flag on the boot partition.

      # @!attribute append
      #   @return [String,nil] kernel parameters to add at the end of the boot entries.

      # @!attribute boot_boot
      #   @return [String,nil] write GRUB 2 to a separate `/boot` partition if it exists.
      #     ("true" or "false")

      # @!attribute boot_custom
      #   @return [String,nil] name of device to write GRUB 2 to (e.g., "/dev/sda3").

      # @!attribute boot_extended
      #   @return [String,nil] write GRUB 2 to the extended partition ("true" or "false").

      # @!attribute boot_mbr
      #   @return [String,nil] write GRUB 2 to the MBR of the first disk in the device map
      #     ("true" or "false").

      # @!attribute boot_root
      #   @return [String,nil] write GRUB 2 to root (`/`) partition ("true" or "false").

      # @!attribute generic_mbr
      #   @return [Boolean,nil] write generic boot code to the MBR (ignored is `boot_mbr` is
      #     set to "true").

      # @!attribute gfxmode
      #   @return [String,nil] graphical resolution of the GRUB 2 screen.

      # @!attribute hiddenmenu
      #   @return [String,nil] whether to hide the bootloder menu.

      # @!attribute os_prober
      #   @return [Boolean,nil] whether to search for already installed operating systems

      # @!attribute cpu_mitigations
      #   @return [String,nil] set of kernel boot command lines parameters for CPU mitigations
      #     ("auto", "nosmt", "off" and "manual").

      # @!attribute serial
      #   @return [String,nil] command to execute if the GRUB 2 terminal mode is set to "serial".

      # @!attribute secure_boot
      #   @return [String,nil] whether to enable/disable UEFI secure boot (only for `grub2-efi`
      #     loader). It is set to "false", it disables the secure boot ("true" or "false").

      # @!attribute terminal
      #   @return [String,nil] GRUB 2 terminal mode to use ("console", "gfxterm" and "serial").

      # @!attribute timeout
      #   @return [Integer,nil] timeout in seconds until automatic boot.

      # @!attribute trusted_boot
      #   @return [String,nil] use Trusted GRUB (only for `grub2` loader type). Valid values
      #     are "true" and "false".

      # @!attribute vgamode
      #   @return [String,nil] `vga` kernel parameter (e.g., "0x317").

      # @!attribute xen_append
      #   @return [String,nil] kernel parameters to add at the end of boot entries for Xen
      #     guests (e.g., "nomodeset vga=0317")

      # @!attribute xen_kernel_append
      #   @return [String,nil] kernel parameters to add at the end of boot entries for Xen
      #     kernels on the VM host server (e.g., "dom0_mem=768").
    end
  end
end
