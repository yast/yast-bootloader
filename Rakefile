require "yast/rake"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["doc/autodocs"] = conf.install_doc_dir
  # Commit to the storage-ng project
  conf.obs_project = "YaST:storage-ng"
  # Make sure 'rake osc:sr' fails
  conf.obs_sr_project = nil
  # TODO: improve it, at least do not get worse
  # TODO: remove condition when new packaging tasks are accepted to factory
  conf.documentation_minimal = 50 if conf.respond_to?(:documentation_minimal=)
end
