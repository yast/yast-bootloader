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

require_relative "../test_helper"
require "bootloader/auto_client"

describe Bootloader::AutoClient do
  describe "#import" do
    let(:data) { { "loader_type" => "grub2-efi" } }
    let(:imported) { true }

    before do
      allow(Yast::Bootloader).to receive(:Import).and_return(imported)
    end

    it "imports the configuration" do
      expect(Yast::Bootloader).to receive(:Import).with(data).and_return(true)
      expect(subject.import(data)).to eq(true)
    end

    it "adds needed packages for installation" do
      expect(Yast::PackagesProposal).to receive(:AddResolvables)
        .with("yast2-bootloader", :package, Array)
      subject.import(data)
    end

    context "when importing the configuration fails" do
      let(:imported) { false }

      it "returns true" do
        expect(subject.import(data)).to eq(true)
      end

      it "does not add any package for installation" do
        expect(Yast::PackagesProposal).to_not receive(:AddResolvables)
        subject.import(data)
      end
    end
  end
end
