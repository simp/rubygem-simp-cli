# creates libkv-enabled production and dev SIMP Omni environments, each
# with two libkv file backends
shared_examples 'kv test environments set up' do |master|

  context 'module installation from fixtures staging dir' do
    let(:module_staging_dir) { '/root/fixtures/modules' }
    let(:envs_dir) { '/etc/puppetlabs/code/environments' }
    let(:base_hiera) { {
      'libkv::backend::file_default' => {
        'type'      => 'file',
        'id'        => 'default',
        'root_path' => '/var/simp/libkv/file/default'
      },
      'libkv::backend::file_custom' => {
        'type'      => 'file',
        'id'        => 'custom',
        'root_path' => '/var/simp/libkv/file/custom'
      },

      'libkv::options' => {
        'softfail'    => false,
        'backends' => {
          'default' => "%{alias('libkv::backend::file_default')}",
          'custom'  => "%{alias('libkv::backend::file_custom')}"
        }
      }

    } }

    let(:create_options_base) { {
      :envs_dir           => envs_dir,
      :module_staging_dir => module_staging_dir,
      :modules_to_copy    => [
        'libkv',
        'kv_test',
        'simplib',
        'stdlib'
      ],
      :hieradata         => base_hiera
    }}


    it "should create 'production' environment" do
      # remove anything in production Puppet env so we start clean
      on(master, "rm -rf #{envs_dir}/production")

      opts = create_options_base.dup
      opts[:env] = 'production'
      create_env_and_install_modules(master, opts)
    end

    it "should create 'dev' environment" do
      opts = create_options_base.dup
      opts[:env] = 'dev'
      create_env_and_install_modules(master, opts)
    end

    it 'should create libkv directory fully accessible by Puppet for file plugin' do
      # Can't do this in the kv_test class, because libkv::xxx functions run
      # during compilation and will fail before the manifest
      # apply can create the directory!  In other words, the libkv functions need
      # the directory to be available at compile time.
      on(master, 'mkdir -p /var/simp/libkv')
      on(master, 'chown root:puppet /var/simp/libkv')
      on(master, 'chmod 0770 /var/simp/libkv')
    end
  end
end
