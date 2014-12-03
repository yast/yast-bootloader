ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

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
  tm = eval(File.read(path))
  allow(Yast::Storage).to receive(:GetTargetMap).and_return(tm)
end
