require "yast/rake"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["doc/autodocs"] = conf.install_doc_dir
  # Commit to the storage-ng project
  conf.obs_project = "YaST:storage-ng"
  # Make sure 'rake osc:sr' fails
  conf.obs_sr_project = nil
end
