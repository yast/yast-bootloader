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

require_relative "../../test_helper"
require "bootloader/autoinst_profile/global_section"
require "bootloader/autoinst_profile/bootloader_section"

describe Bootloader::AutoinstProfile::BootloaderSection do
  describe ".new_from_hashes" do
    let(:hash) do
      {
        "loader_type" => "grub2",
        "global"      => { "activate" => true, "append" => "nomodeset" },
        "device_map"  => [
          "linux" => "/dev/sda", "firmware" => "hd0"
        ]
      }
    end

    it "sets the attributes" do
      section = described_class.new_from_hashes(hash)
      expect(section.loader_type).to eq("grub2")
    end

    it "sets the global section" do
      section = described_class.new_from_hashes(hash)
      global = section.global
      expect(global).to be_a(Bootloader::AutoinstProfile::GlobalSection)
      expect(global.activate).to eq(true)
      expect(global.parent).to eq(section)
    end

    it "sets the device map entries" do
      section = described_class.new_from_hashes(hash)
      entry = section.device_map.first
      expect(entry.linux).to eq("/dev/sda")
      expect(entry.parent).to eq(section)
    end
  end
end
