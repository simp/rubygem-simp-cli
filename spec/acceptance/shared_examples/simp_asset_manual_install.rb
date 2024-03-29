# install assets listed in fixtures and copied over into modules dir
#
shared_examples 'simp asset manual install' do |server|

  context 'asset installation from fixtures staging dir' do
    let(:asset_staging_dir) { '/root/fixtures/assets' }
    let(:skeleton_dir) { '/usr/share/simp/environment-skeleton' }

    it 'should ensure packages required by assets are installed' do
      [
        'git',
        'rsync'
      ].each do |package|
        install_package_unless_present_on(server, package)
      end
    end

    it 'should install simp-adapter as done by its RPM' do
      on(server, "cp #{asset_staging_dir}/adapter/src/sbin/simp_rpm_helper /usr/local/sbin/simp_rpm_helper")
      on(server, 'chmod 750 /usr/local/sbin/simp_rpm_helper')
      on(server, 'mkdir -p /etc/simp')
      on(server, "cp #{asset_staging_dir}/adapter/src/conf/adapter_conf.yaml /etc/simp/adapter_conf.yaml")
      on(server, 'chmod 640 /etc/simp/adapter_conf.yaml')
    end

    it 'should create skeleton dir' do
      on(server, "mkdir -p #{skeleton_dir}")
    end

    it 'should install simp-environment-skeleton as done by its RPM' do
      on(server, "cp -r #{asset_staging_dir}/environment_skeleton/environments/puppet #{skeleton_dir}")
      on(server, "cp -r #{asset_staging_dir}/environment_skeleton/environments/secondary #{skeleton_dir}")
      on(server, "mkdir -p #{skeleton_dir}/writable/simp_autofiles")
      on(server, "mkdir -p #{skeleton_dir}/secondary/site_files/krb5_files/files/keytabs")
      on(server, "mkdir -p #{skeleton_dir}/secondary/site_files/pki_files/files/keydist/cacerts")
      on(server, "cp -r #{asset_staging_dir}/environment_skeleton/environments/secondary #{skeleton_dir}")
      on(server, "chmod -R g+rX,o-rwx #{skeleton_dir}")
    end

    it 'should install simp-rsync-skeleton as done by its RPM' do
      on(server, "cp -r #{asset_staging_dir}/rsync_data/rsync #{skeleton_dir}")
      on(server, "chmod -R g+rX,o-rwx #{skeleton_dir}/rsync")
    end

    it "should build SIMP's selinux contexts as done by simp-selinux-policy RPM" do
      server.install_package('yum-utils')
      # NOTE:
      # - For this test, we don't need to revert to the original versions
      #   of the selinux build dependencies for the major OS version. We
      #   bypass the version downgrades using SIMP_ENV_NO_SELINUX_DEPS=yes.
      # - yum-builddep temporarily enables all repos to do its work.
      #   Unfortunately, the puppet[5,6]-source repo isn't set up correctly
      #   and the easiest way to exclude this repo during this command
      #   is to add the --disablerepo=puppet[5,6] option. (For some odd
      #   reason --disablerepo=puppet[5,6]-source didn't work...)
      yum_cmd = [
        'SIMP_ENV_NO_SELINUX_DEPS=yes',
        'yum-builddep -y',
        "#{asset_staging_dir}/simp_selinux_policy/build/simp-selinux-policy.spec",
        "--disablerepo=#{ENV.fetch('BEAKER_PUPPET_COLLECTION', 'puppet5')}"
      ].join(' ')
      on(server, yum_cmd)

      build_command = [
        "cd #{asset_staging_dir}/simp_selinux_policy/build/selinux",
        'make -f /usr/share/selinux/devel/Makefile'
      ].join('; ')
      on(server, build_command)
    end

    it "should install SIMP's selinux contexts as done by simp-selinux-policy RPM" do
      file_install_cmd = [
        'install -p -m 644 -D',
        "#{asset_staging_dir}/simp_selinux_policy/build/selinux/simp.pp",
        '/usr/share/selinux/packages/simp.pp'
      ].join(' ')
      on(server, file_install_cmd)
      on(server, "#{asset_staging_dir}/simp_selinux_policy/sbin/set_simp_selinux_policy install")
    end

    it 'should install simp-cli and highline gems in /usr/share/simp/ruby' do
      gemdir = '/usr/share/simp/ruby'
      on(server, "mkdir -p #{gemdir}")
      cmd_prefix = [
        '/opt/puppetlabs/puppet/bin/gem',
        'install',
        '--local',
        "--install-dir #{gemdir}",
        '--force'
      ].join(' ')

      # install only the latest simp-cli and highline gems available, not all,
      # or the /bin/simp script will fail!
      cmd = "ls #{asset_staging_dir}/rubygem_simp_cli/dist/simp-cli*gem | tail -n 1"
      simp_cli_gem = on(server, cmd).stdout.strip
      on(server, "#{cmd_prefix} #{simp_cli_gem}")
      cmd = "ls #{asset_staging_dir}/rubygem_simp_cli/dist/highline*gem | tail -n 1"
      highline_gem = on(server, cmd).stdout.strip
      on(server, "#{cmd_prefix} #{highline_gem}")
    end

    it "should install 'simp' script similar to that done by the rubygem-simp-cli RPM" do
      simp_script = <<~EOM
        #!/bin/bash

        PATH=/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH

        /usr/share/simp/ruby/gems/simp-cli-*/bin/simp $@

      EOM
      create_remote_file(server, '/bin/simp', simp_script)
      on(server, 'chmod +x /bin/simp')
    end
  end
end
