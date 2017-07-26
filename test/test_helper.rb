ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

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
    if mocks.respond_to?(:verify_partial_doubles=)
      mocks.verify_partial_doubles = true
    end
  end
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../../src", __FILE__)
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

def target_map_stub(name)
  path = File.join(File.dirname(__FILE__), "data", name)
  tm = YAML.load(File.read(path))
  allow(Yast::Storage).to receive(:GetTargetMap).and_return(tm)
end

def devicegraph_stub(name)
  path = File.join(File.dirname(__FILE__), "data", "storage-ng", name)
  Y2Storage::StorageManager.create_test_instance.probe_from_yaml(path)
  # clears cache for storage devices
  Yast::BootStorage.reset_disks
end

def mock_disk_partition
  # simple mock getting disks from partition as it need initialized libstorage
  allow(Yast::Storage).to receive(:GetDiskPartition) do |partition|
    case partition
    when "/dev/system/root"
      disk = "/dev/system"
      number = "system"
    when "/dev/mapper/cr_swap"
      disk = "/dev/sda"
      number = "1"
    when "tmpfs"
      disk = "tmpfs"
      number = ""
    else
      number = partition[/(\d+)$/, 1] || ""
      disk = partition[0..-(number.size + 1)]
    end
    { "disk" => disk, "nr" => number }
  end

  allow(Yast::Storage).to receive(:GetContVolInfo).and_return(false)
end

# stub udev mapping everywhere
RSpec.configure do |config|
  Yast.import "BootStorage"
  Yast.import "Bootloader"
  require "bootloader/udev_mapping"
  require "bootloader/stage1_device"

  config.before do
    allow(::Bootloader::UdevMapping).to receive(:to_mountby_device) { |d| d }
    allow(::Bootloader::UdevMapping).to receive(:to_kernel_device) { |d| d }
    allow(::Bootloader::Stage1Device).to receive(:new) { |d| double(real_devices: [d]) }
    devicegraph_stub("trivial.yaml")
  end
end
