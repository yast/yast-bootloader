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
require "bootloader/autoinst_profile/global_section"
require "bootloader/autoinst_profile/device_map_entry_section"

module Bootloader
  module AutoinstProfile
    # This class represents an AutoYaST `<bootloader>` section
    #
    class BootloaderSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :loader_type },
          { name: :loader_device }, # deprecated
          { name: :activate }, # deprecated
          { name: :sections } # deprecated
        ]
      end

      define_attr_accessors

      # @!attribute loader_type
      #   @return [String] which boot loader to use (default, grub2, grub2-efi and none)
      #   @see Bootloader::BootloaderFactory::SUPPORTED_BOOTLOADERS

      # @!attribute loader_device
      #   @deprecated Replaced by `<boot_*>` elements in the `<global>` section.

      # @!attribute activate
      #   @see GlobalSection#activate
      #   @deprecated

      # @!attribute sections
      #   @deprecated It still exists just to log a warning in AutoyastConverter.

      # @return [GlobalSection] 'global' section
      attr_accessor :global
      # @return [Array<DeviceMapEntrySection>] 'device_map' list
      attr_accessor :device_map

      # Creates an instance based on the profile representation used by the AutoYaST modules
      # (hash with nested hashes and arrays).
      #
      # @param hash [Hash] Bootloader section from an AutoYaST profile
      # @return [Bootloader]
      def self.new_from_hashes(hash)
        result = new
        result.init_from_hashes(hash)
        result
      end

      # Constructor
      def initialize
        @device_map = []
      end

      # Method used by {.new_from_hashes} to populate the attributes.
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        super
        @device_map = hash.fetch("device_map", []).map do |entry|
          DeviceMapEntrySection.new_from_hashes(entry, self)
        end
        @global = GlobalSection.new_from_hashes(hash["global"] || {}, self)
      end
    end
  end
end
