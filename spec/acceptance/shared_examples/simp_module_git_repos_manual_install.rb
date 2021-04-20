# install modules listed in fixtures to /usr/share/simp and then
# run simp_rpm_helper to create local git repos
#
shared_examples 'simp module git repos manual install' do |server|

  context 'module installation from fixtures staging dir' do
    let(:module_staging_dir) { '/root/fixtures/modules' }
    let(:module_share_dir) { '/usr/share/simp/modules' }

    # simp cli will need r10k to access modules in local git repos created
    # by simp_rpm_helper in step below
    it "should install git RPM and r10k gem into Puppet's Ruby" do
      server.install_package('git')
      on(server, 'puppet resource package r10k ensure=present provider=puppet_gem')
    end

    it 'should install modules as done by their RPMs' do
      modules = on(server, "ls #{module_staging_dir}").stdout.split("\n")
      modules.delete_if { |name| name.match(%r(.tar$)) }
      on(server, "mkdir -p #{module_share_dir}")
      modules.each do |name|
        on(server, "cp -r #{module_staging_dir}/#{name} #{module_share_dir}/#{name}")
        cmd = [
          '/usr/local/sbin/simp_rpm_helper',
          "--rpm_dir=#{module_share_dir}/#{name}",
          "--rpm_section='posttrans'",
          '--rpm_status=1'
        ].join(' ')

        on(server, cmd)
      end
    end
  end
end
