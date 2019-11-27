# install assets listed in fixtures and copied over into modules dir
#
shared_examples 'simp asset manual install' do |master|

  context 'asset installation from fixtures staging dir' do
    let(:asset_staging_dir) { '/root/fixtures/assets' }
    let(:skeleton_dir) { '/usr/share/simp/environment-skeleton' }

    it 'should create skeleton dir' do
      on(master, "mkdir -p #{skeleton_dir}")
    end

    it 'should install simp-environment-skeleton as done by its RPM' do
      on(master, "cp -r #{asset_staging_dir}/environment_skeleton/environments/puppet #{skeleton_dir}")
      on(master, "cp -r #{asset_staging_dir}/environment_skeleton/environments/secondary #{skeleton_dir}")
      on(master, "mkdir -p #{skeleton_dir}/writable/simp_autofiles")
      on(master, "mkdir -p #{skeleton_dir}/secondary/site_files/krb5_files/files/keytabs")
      on(master, "mkdir -p #{skeleton_dir}/secondary/site_files/pki_files/files/keydist/cacerts")
      on(master, "cp -r #{asset_staging_dir}/environment_skeleton/environments/secondary #{skeleton_dir}")
      on(master, "chmod -R g+rX,o-rwx #{skeleton_dir}")
    end

    it 'should install simp-rsync-skeleton as done by its RPM' do
      on(master, "cp -r #{asset_staging_dir}/rsync_data/rsync #{skeleton_dir}")
      on(master, "chmod -R g+rX,o-rwx #{skeleton_dir}/rsync")
    end

    it "should build SIMP's selinux contexts as done by simp-selinux-policy RPM" do
      master.install_package('yum-utils')
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
      on(master, yum_cmd)

      build_command = [
        "cd #{asset_staging_dir}/simp_selinux_policy/build/selinux",
        'make -f /usr/share/selinux/devel/Makefile'
      ].join('; ')
      on(master, build_command)
    end

    it "should install SIMP's selinux contexts as done by simp-selinux-policy RPM" do
      file_install_cmd = [
        'install -p -m 644 -D',
        "#{asset_staging_dir}/simp_selinux_policy/build/selinux/simp.pp",
        '/usr/share/selinux/packages/simp.pp'
      ].join(' ')
      on(master, file_install_cmd)
      on(master, "#{asset_staging_dir}/simp_selinux_policy/sbin/set_simp_selinux_policy install")
    end

    it "should install 'simp' script similar to that done by the rubygem-simp-cli RPM" do
      # This is a ninja hack to create a working /bin/simp.  We don't
      # need to create and install the gems in rubygem-simp-cli.  We
      # simply need to create the script pointing to our staged
      # rubygem-simp-cli clone.
      #
      simp_script = <<-EOM
#!/bin/bash

PATH=/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH

#{asset_staging_dir}/rubygem_simp_cli/bin/simp $@

      EOM
      create_remote_file(master, '/bin/simp', simp_script)
      on(master, 'chmod +x /bin/simp')
    end
  end
end
