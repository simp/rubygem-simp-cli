# creates simpkv-enabled production and dev SIMP Omni environments, each
# with two simpkv file backends
shared_examples 'kv test environments set up' do |server|

  context 'module installation from fixtures staging dir' do
    let(:module_staging_dir) { '/root/fixtures/modules' }
    let(:envs_dir) { '/etc/puppetlabs/code/environments' }
    let(:base_hiera) { {
      'simpkv::backend::file_default' => {
        'type'      => 'file',
        'id'        => 'default',
        'root_path' => '/var/simp/simpkv/file/default'
      },
      'simpkv::backend::file_custom' => {
        'type'      => 'file',
        'id'        => 'custom',
        'root_path' => '/var/simp/simpkv/file/custom'
      },

      'simpkv::options' => {
        'softfail'    => false,
        'backends' => {
          'default' => "%{alias('simpkv::backend::file_default')}",
          'custom'  => "%{alias('simpkv::backend::file_custom')}"
        }
      }

    } }

    let(:create_options_base) { {
      :envs_dir           => envs_dir,
      :module_staging_dir => module_staging_dir,
      :modules_to_copy    => [
        'simpkv',
        'kv_test',
        'simplib',
        'stdlib'
      ],
      :hieradata         => base_hiera
    }}


    it "should create 'production' environment" do
      # remove anything in production Puppet env so we start clean
      on(server, "rm -rf #{envs_dir}/production")

      opts = create_options_base.dup
      opts[:env] = 'production'
      create_env_and_install_modules(server, opts)
    end

    it "should create 'dev' environment" do
      opts = create_options_base.dup
      opts[:env] = 'dev'
      create_env_and_install_modules(server, opts)
    end

    it 'should create simpkv directory fully accessible by Puppet for file plugin' do
      # Can't do this in the kv_test class, because simpkv::xxx functions run
      # during compilation and will fail before the manifest
      # apply can create the directory!  In other words, the simpkv functions need
      # the directory to be available at compile time.
      on(server, 'mkdir -p /var/simp/simpkv')
      on(server, 'chown root:puppet /var/simp/simpkv')
      on(server, 'chmod 0770 /var/simp/simpkv')
    end
  end
end
