# frozen_string_literal: true

ENV["Y2DIR"] = File.expand_path("../src", __dir__)

# localization agnostic tests
ENV["LC_ALL"] = "en_US.utf-8"
ENV["LANG"] = "en_US.utf-8"

require "yast"
require "yast/rspec"
require "yaml"
require "y2storage"

# force utf-8 encoding for external
Encoding.default_external = Encoding::UTF_8

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # If you misremember a method name both in code and in tests,
    # will save you.
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    #
    # With graceful degradation for RSpec 2
    mocks.verify_partial_doubles = true if mocks.respond_to?(:verify_partial_doubles=)
  end
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../src", __dir__)
  # track all ruby files under src
  SimpleCov.track_files("#{src_location}/**/*.rb")

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end

def devicegraph_stub(name)
  path = File.join(File.dirname(__FILE__), "data", name)
  if path.end_with?(".xml")
    Y2Storage::StorageManager.create_test_instance.probe_from_xml(path)
  else
    Y2Storage::StorageManager.create_test_instance.probe_from_yaml(path)
  end
end

def find_device(name)
  graph = Y2Storage::StorageManager.instance.staging
  Y2Storage::BlkDevice.find_by_name(graph, name)
end

# stub module to prevent its Import
# Useful for modules from different yast packages, to avoid build dependencies
def stub_module(name, fake_class = nil)
  fake_class = Class.new { def self.fake_method; end } if fake_class.nil?
  Yast.const_set name.to_sym, fake_class
end

AutoInstallStub = Class.new do
  def self.issues_list
    []
  end
end
stub_module("AutoInstall", AutoInstallStub)

# stub udev mapping everywhere
RSpec.configure do |config|
  Yast.import "BootStorage"
  Yast.import "Bootloader"
  require "bootloader/udev_mapping"

  config.before do
    Yast::BootStorage.instance_variable_set(:@storage_revision, nil)
    allow(::Bootloader::UdevMapping).to receive(:to_mountby_device) { |d| d }
    allow(::Bootloader::UdevMapping).to receive(:to_kernel_device) { |d| d }
    devicegraph_stub("trivial.yaml")
  end
end
