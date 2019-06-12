#! /usr/bin/env rspec
# typed: false

require_relative "test_helper"

require "bootloader/generic_widgets"
require "cwm/rspec"

describe Bootloader::LoaderTypeWidget do
  before do
    allow(Bootloader::BootloaderFactory)
      .to receive(:current)
      .and_return(double("TestBL", name: "test", propose: nil))
  end

  include_examples "CWM::ComboBox"
end
