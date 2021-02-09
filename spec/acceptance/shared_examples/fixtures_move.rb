# move fixtures copies into a staging dir
#
shared_examples 'fixtures move' do |master|

  context 'staging of fixtures' do
    let(:fixtures_orig_dest) { '/etc/puppetlabs/code/environments/production/modules' }
    let(:fixtures_staging_dir) { '/root/fixtures' }

    it 'should move assets from fixtures install dir to staging dir' do
      on(master, "mkdir -p #{fixtures_staging_dir}/assets")
      on(master, "mv #{fixtures_orig_dest}/environment_skeleton #{fixtures_staging_dir}/assets")
      on(master, "mv #{fixtures_orig_dest}/rsync_data #{fixtures_staging_dir}/assets")
      on(master, "mv #{fixtures_orig_dest}/rubygem_simp_cli #{fixtures_staging_dir}/assets")
      on(master, "mv #{fixtures_orig_dest}/simp_selinux_policy #{fixtures_staging_dir}/assets")
    end

    it 'should move modules from fixtures install dir to staging dir' do
      on(master, "mkdir -p #{fixtures_staging_dir}/modules")
      on(master, "mv #{fixtures_orig_dest}/* #{fixtures_staging_dir}/modules")
    end
  end
end
