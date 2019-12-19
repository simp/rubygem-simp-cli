module Acceptance; end
module Acceptance::Helpers; end
module Acceptance::Helpers::EnvHelper

  # @param host Host object on which environment will be created
  # @param opts Options Hash with the following keys:
  #   :env = Puppet environment name
  #   :envs_dir = Parent directory of Puppet environments
  #   :hieradata = Hash of hieradata to be installed as default.yaml in the
  #     environment's data directory
  #   :modules_staging_dir = Staging dir containing Puppet modules to be copied
  #     into the envirnment
  def create_env_and_install_modules(host, opts)
    on(host, "simp environment new --skeleton --no-puppetfile-gen #{opts[:env]}")

    modules_dir =  File.join(opts[:envs_dir], opts[:env], 'modules')
    on(host, "mkdir -p #{modules_dir}")
    opts[:modules_to_copy].each do |mod|
      on(host, "cp -r #{opts[:module_staging_dir]}/#{mod} #{modules_dir}")
    end

    default_yaml_filename =  File.join(opts[:envs_dir], opts[:env], 'data',
      'default.yaml')
    create_remote_file(host, default_yaml_filename, opts[:hieradata].to_yaml)

    # Remove includes for simp_options, simp, and compliance_markup
    # classes from site.pp as we are not using any of those classes here
    site_pp = File.join(opts[:envs_dir], opts[:env], 'manifests', 'site.pp')
    on(host, "sed -i \"/^include 'simp_options'$/d\" #{site_pp}")
    on(host, "sed -i \"/^include 'simp'$/d\" #{site_pp}")
    on(host, "sed -i \"/^include compliance_markup$/d\" #{site_pp}")

    # Fix permissions of anything we created in the Puppet environment
    on(host, "simp environment fix #{opts[:env]} --no-writable --no-writable")
  end
end
