ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "yaml"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start

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
end
