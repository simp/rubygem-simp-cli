require 'spec_helper_acceptance'
require 'inifile'
require 'yaml'

test_name 'simp config defaults for (mock) ISO install'

host_interfaces = {}
hosts.each do |host|
  host_interfaces[host] = fact_on(host, 'interfaces').split(',').delete_if { |x| x == 'lo' }
end


# Tests `simp config`, alone, in a server configuration that is akin to
# installation from SIMP ISO.
#
# - Mocks the 2 attributes that define a SIMP ISO installation
#   - Existence of /etc/yum.repos.d/simp_filesystem.repo
#   - Existence of 'simp' local user.
# - Mocks /var/www/yum/
# - Does not do extensive permutation testing, as the non-ISO tests
#   effectively test the permutations that would apply here.
# - The minimal server set up only has modules and assets required for
#   the limited `simp config` testing done here.
# - Does NOT support network configuration via `simp config`.
# - Does NOT support `simp bootstrap` testing. Bootstrap tests must install
#   most of the components in one of simp-core's Puppetfiles in order to
#   have everything needed for bootstrap testing. See simp-core acceptance
#   tests for bootstrap tests.
#
# WARNING: This test will disable CentOS yum repos!
#
describe 'simp config defaults for (mock) ISO install' do
  context 'pre-test mock ISO setup' do
    it 'ensures packages required for UpdateOsYumRepositoriesAction Item are installed' do
      # for yum-config-manager
      install_package_unless_present_on(hosts, 'yum-utils')

      # for createrepo; will install createrepo_c package on EL > 7
      install_package_unless_present_on(hosts, 'createrepo')

      # for apache group used when fixing permissions on created repo
      install_package_unless_present_on(hosts, 'httpd')
    end

    it 'creates a mock simp_filesystem.repo' do
      # presence of the repo file is all that is checked, not the content!
      on(hosts, 'mv /etc/yum.repos.d/puppet*.repo /etc/yum.repos.d/simp_filesystem.repo')
    end

    it 'creates /var/www/yum tree for os' do
      hosts.each do |host|
        os     = fact_on(host, 'operatingsystem')
        os_rel = fact_on(host, 'operatingsystemrelease')
        arch   = fact_on(host, 'architecture')
        yumpath = "/var/www/yum/#{os}/#{os_rel}/#{arch}"
        on(host, "mkdir -p #{yumpath}")
      end
    end

    # Need RPMs to verify the RPM links are created. However since the code
    # to create repos is expected to go away, leave empty.
    it 'populates RPMs in /var/www/yum tree'

    it 'creates a local simp user' do
      on(hosts, 'puppet resource user simp ensure=present home=/var/local/simp managehome=true shell=/bin/bash')
    end
  end

  context "with defaults on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description  => 'with defaults',
        :iso_install  => true,
        :interface    => host_interfaces[host].first
      }

      include_examples 'simp config operation', host, options

      it 'should disable CentOS repos' do
        repo_files = on(host, 'ls /etc/yum.repos.d/CentOS*').stdout.split("\n")
        # IniFile can't parse the CentOS*-Media.repo files, arrrrgh. So, until
        # we find a better INI gem, just exclude these repo files from the list
        # to check.
        repo_files.delete_if { |repo_file| !repo_file.match(%r{^/etc/yum.repos.d/CentOS.*-Media.repo$}).nil? }
        enabled_repos = {}
        repo_files.each do |repo_file|
          repo_ini = IniFile.new({:content => file_contents_on(host, repo_file)})
          repo_names = repo_ini.sections
          repo_names.each do |repo_name|
            # if 'enabled' missing or set to 1, repo is enabled
            repo_enabled = (repo_ini[repo_name]['enabled'] != 0)
            if repo_enabled
              enabled_repos[repo_file] = [] unless enabled_repos.key?(repo_file)
              enabled_repos[repo_file] << repo_name
            end
          end
        end

        # for debug
        puts "Enabled repos: #{enabled_repos.to_yaml}" unless enabled_repos.empty?
        expect( enabled_repos ).to be_empty
      end


      # This code should be going away when EL8 repos are addressed,
      # so don't expend effort to test
      it 'should set up a yum repo in /var/www/yum'
    end
  end
end
