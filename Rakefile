require "yast/rake"

Yast::Tasks.configuration do |conf|
  #lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["doc/autodocs"] = conf.install_doc_dir
end
