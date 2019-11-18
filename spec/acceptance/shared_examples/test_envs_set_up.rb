# create 3 test environments:
# * old_simplib:                 simplib with only legacy passgen
# * new_simplib_legacy_passgen:  libkv-enabled simplib::passgen in legacy mode
# * new_simplib_libkv_passgen:   libkv-enabled simplib::passgen in libkv mode

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

shared_examples 'test environments set up' do |master|

  context 'module installation from fixtures staging dir' do
    let(:module_staging_dir) { '/root/fixtures/modules' }
    let(:envs_dir) { '/etc/puppetlabs/code/environments' }
    let(:create_options_base) { {
      :envs_dir           => envs_dir,
      :module_staging_dir => module_staging_dir
    }}

    let(:base_hiera) { {
      'classes' => [ 'passgen_test' ]
    } }

    let(:libkv_hiera) { {

        'libkv::backend::file_default' => {
          'type'      => 'file',
          'id'        => 'default',
          'root_path' => '/var/simp/libkv/file/default'
        },

       'libkv::options' => {
          'environment' => '%{server_facts.environment}',
          'softfail'    => false,
          'backends' => {
            'default' => "%{alias('libkv::backend::file_default')}"
          }
        }

    } }

    it 'should clone old simplib into fixtures staging dir' do
      # install last simplib version that contains legacy simplib::passgen
      master.install_package('git')
      cmd = "cd #{module_staging_dir}; " +
        'git clone https://github.com/simp/pupmod-simp-simplib simplib-3.15.3'
      on(master, cmd)

      cmd = "cd #{module_staging_dir}/simplib-3.15.3; git checkout tags/3.15.3"
      on(master, cmd)
    end

    it 'should create old_simplib environment' do
      opts = create_options_base.dup
      opts[:env] = 'old_simplib'
      opts[:modules_to_copy] = [
        'passgen_test',
        'simplib-3.15.3',
        'stdlib'
      ]

      opts[:hieradata] = base_hiera.dup

      create_env_and_install_modules(master, opts)

      # Fix name of simplib module
      modules_dir = File.join(opts[:envs_dir], opts[:env], 'modules')
      cmd = ['mv',
        File.join(modules_dir, 'simplib-3.15.3'),
        File.join(modules_dir, 'simplib')
      ].join(' ')
      on(master, cmd)
    end

    it 'should create new_simplib_legacy_passgen environment' do
      opts = create_options_base.dup
      opts[:env] = 'new_simplib_legacy_passgen'
      opts[:modules_to_copy] = [
        'libkv',
        'passgen_test',
        'simplib',
        'stdlib'
      ]

      default_hiera = base_hiera.dup
      default_hiera['simplib::passgen::libkv'] = false
      default_hiera.merge!(libkv_hiera)
      opts[:hieradata] = default_hiera

      create_env_and_install_modules(master, opts)
    end

    it 'should create new_simplib_libkv_passgen environment' do
      opts = create_options_base.dup
      opts[:env] = 'new_simplib_libkv_passgen'
      opts[:modules_to_copy] = [
        'libkv',
        'passgen_test',
        'simplib',
        'stdlib'
      ]

      default_hiera = base_hiera.dup
      default_hiera['simplib::passgen::libkv'] = true
      default_hiera.merge!(libkv_hiera)
      opts[:hieradata] = default_hiera

      create_env_and_install_modules(master, opts)
    end

    it 'should create libkv directory fully accessible by Puppet for file plugin' do
      # Can't do this in the passgen_test class, because simplib::passgen
      # functions run during compilation and will fail before the manifest
      # apply can create the directory!  In other words, the libkv functions need
      # the directory to be available at compile time.
      on(master, 'mkdir -p /var/simp/libkv')
      on(master, 'chown root:puppet /var/simp/libkv')
      on(master, 'chmod 0770 /var/simp/libkv')
    end
  end
end
