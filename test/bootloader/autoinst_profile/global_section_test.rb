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

describe Bootloader::AutoinstProfile::GlobalSection do
  let(:parent) { instance_double(Bootloader::AutoinstProfile::BootloaderSection) }

  describe ".new_from_hashes" do
    let(:hash) { { "activate" => true, "append" => "nomodeset" } }

    it "sets the attributes" do
      section = described_class.new_from_hashes(hash)
      expect(section.activate).to eq(true)
      expect(section.append).to eq("nomodeset")
    end

    it "sets the parent" do
      section = described_class.new_from_hashes(hash, parent)
      expect(section.parent).to eq(parent)
    end
  end
end
