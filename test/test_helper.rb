ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "yast/rspec"
require "yaml"

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

  # for coverage we need to load all ruby files
  src_location = File.expand_path("../../src", __FILE__)
  Dir["#{src_location}/{module,lib}/**/*.rb"].each { |f| require_relative f }

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
    allow(::Yast::Bootloader).to receive(:checkUsedStorage).and_return(true)
    allow(Yast::BootStorage).to receive(:detect_disks) # do not do real disk detection
  end
end
