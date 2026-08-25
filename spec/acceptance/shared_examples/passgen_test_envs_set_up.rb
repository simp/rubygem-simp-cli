# frozen_string_literal: true

# create 3 test environments:
# * old_simplib:                 simplib with only legacy passgen
# * new_simplib_legacy_passgen:  simpkv-enabled simplib::passgen in legacy mode
# * new_simplib_simpkv_passgen:   simpkv-enabled simplib::passgen in simpkv mode

shared_examples 'passgen test environments set up' do |server|
  context 'module installation from fixtures staging dir' do
    let(:module_staging_dir) { '/root/fixtures/modules' }
    let(:envs_dir) { '/etc/puppetlabs/code/environments' }
    let(:create_options_base) do
      {
        :envs_dir => envs_dir,
        :module_staging_dir => module_staging_dir
      }
    end

    let(:base_hiera) do
      {
        'classes' => ['passgen_test']
      }
    end

    let(:simpkv_hiera) do
      {
        'simpkv::backend::file_default' => {
          'type' => 'file',
          'id' => 'default',
          'root_path' => '/var/simp/simpkv/file/default'
        },

        'simpkv::options' => {
          'environment' => '%{server_facts.environment}',
          'softfail' => false,
          'backends' => {
            'default' => "%{alias('simpkv::backend::file_default')}"
          }
        }
      }
    end

    it 'clones old simplib into fixtures staging dir' do
      # install last simplib version that contains legacy simplib::passgen
      cmd = "cd #{module_staging_dir}; " \
            'git clone https://github.com/simp/pupmod-simp-simplib simplib-3.15.3'
      on(server, cmd)

      cmd = "cd #{module_staging_dir}/simplib-3.15.3; git checkout tags/3.15.3"
      on(server, cmd)
    end

    it 'creates old_simplib environment' do
      opts = create_options_base.dup
      opts[:env] = 'old_simplib'
      opts[:modules_to_copy] = [
        'passgen_test',
        'simplib-3.15.3',
        'stdlib',
      ]

      opts[:hieradata] = base_hiera.dup

      create_env_and_install_modules(server, opts)

      # Fix name of simplib module
      modules_dir = File.join(opts[:envs_dir], opts[:env], 'modules')
      cmd = ['mv',
             File.join(modules_dir, 'simplib-3.15.3'),
             File.join(modules_dir, 'simplib')].join(' ')
      on(server, cmd)
    end

    it 'creates new_simplib_legacy_passgen environment' do
      opts = create_options_base.dup
      opts[:env] = 'new_simplib_legacy_passgen'
      opts[:modules_to_copy] = [
        'simpkv',
        'passgen_test',
        'simplib',
        'stdlib',
      ]

      default_hiera = base_hiera.dup
      default_hiera['simplib::passgen::simpkv'] = false
      default_hiera.merge!(simpkv_hiera)
      opts[:hieradata] = default_hiera

      create_env_and_install_modules(server, opts)
    end

    it 'creates new_simplib_simpkv_passgen environment' do
      opts = create_options_base.dup
      opts[:env] = 'new_simplib_simpkv_passgen'
      opts[:modules_to_copy] = [
        'simpkv',
        'passgen_test',
        'simplib',
        'stdlib',
      ]

      default_hiera = base_hiera.dup
      default_hiera['simplib::passgen::simpkv'] = true
      default_hiera.merge!(simpkv_hiera)
      opts[:hieradata] = default_hiera

      create_env_and_install_modules(server, opts)
    end

    it 'creates simpkv directory fully accessible by Puppet for file plugin' do
      # Can't do this in the passgen_test class, because simplib::passgen
      # functions run during compilation and will fail before the manifest
      # apply can create the directory!  In other words, the simpkv functions need
      # the directory to be available at compile time.
      on(server, 'mkdir -p /var/simp/simpkv')
      on(server, 'chown root:puppet /var/simp/simpkv')
      on(server, 'chmod 0770 /var/simp/simpkv')
    end
  end
end
