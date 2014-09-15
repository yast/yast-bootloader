ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "yast"

def target_map_stub(name)
  path = File.join(File.dirname(__FILE__), "data", name)
  tm = eval(File.read(path))
  allow(Yast::Storage).to receive(:GetTargetMap).and_return(tm)
end


