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
describe 'simp config defaults for (mock) ISO install' do
  context 'pre-test mock ISO setup' do
    it 'creates a mock simp_filesystem.repo' do
      # presence of the repo file is all that is checked, not the content!
      on(hosts, 'mv /etc/yum.repos.d/puppet*.repo /etc/yum.repos.d/simp_filesystem.repo')
    end

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
    end
  end
end
