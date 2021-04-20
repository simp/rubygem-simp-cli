# move fixtures copies into a staging dir
#
shared_examples 'fixtures move' do |master|

  context 'staging of fixtures' do
    let(:fixtures_orig_dest) { '/etc/puppetlabs/code/environments/production/modules' }
    let(:fixtures_staging_dir) { '/root/fixtures' }

    it 'should move assets from fixtures install dir to staging dir' do
      on(master, "mkdir -p #{fixtures_staging_dir}/assets")
      [
        'adapter',
        'environment_skeleton',
        'rsync_data',
        'rubygem_simp_cli',
        'simp_selinux_policy'
      ].each do |asset|
        on(master, "mv #{fixtures_orig_dest}/#{asset} #{fixtures_staging_dir}/assets")
      end
    end

    it 'should move modules from fixtures install dir to staging dir' do
      on(master, "mkdir -p #{fixtures_staging_dir}/modules")
      on(master, "mv #{fixtures_orig_dest}/* #{fixtures_staging_dir}/modules")
    end
  end
end
