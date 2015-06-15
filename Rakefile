require "yast/rake"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
  conf.install_locations["doc/autodocs"] = conf.install_doc_dir
    conf.obs_api = "https://api.suse.de/"
      conf.obs_target = "SLE-12-SP1"
        conf.obs_sr_project = "SUSE:SLE-12:Update"
          conf.obs_project = "Devel:YaST:Head"
end
