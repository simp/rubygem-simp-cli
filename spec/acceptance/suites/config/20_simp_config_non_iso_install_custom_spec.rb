require 'spec_helper_acceptance'
require 'yaml'

test_name 'simp config with customization for non-ISO install'

host_interfaces = {}
hosts.each do |host|
  host_interfaces[host] = fact_on(host, 'interfaces').split(',').delete_if { |x| x == 'lo' }
end


# Tests `simp config`, alone, in a server configuration that is akin to
# installation from RPM.
#
# - The minimal server set up only has modules and assets required for
#   the limited `simp config` testing done here.
# - Does NOT support network configuration via `simp config`.
# - Does NOT support `simp bootstrap` testing. Bootstrap tests must install
#   most of the components in one of simp-core's Puppetfiles in order to
#   have everything needed for bootstrap testing. See simp-core acceptance
#   tests for bootstrap tests.
#
describe 'simp config with customization for non-ISO install' do
  context "without setting grub password on #{host} and --force-config" do
    hosts.each do |host|
      options = {
        :description        => 'without setting grub password and --force-config',
        :set_grub_password  => false,
        :config_opts_to_add => [ '--force-config' ],
        :interface          => host_interfaces[host].first
      }

      include_examples 'simp config operation', host, options
    end
  end

  context "without use of SIMP internet repos on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description             => 'without use of SIMP internet repos',
        :use_simp_internet_repos => false,
        :interface               => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context "when not LDAP server on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description => 'when not LDAP server',
        :ldap_server => false,
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context "with logservers but without failover logservers on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description => 'with logservers but without failover logservers',
        :logservers  => [ '1.2.3.4', '1.2.3.5'],
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context "with logservers and failover logservers on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description         => 'with logservers and failover logservers',
        :logservers          => [ '1.2.3.4', '1.2.3.5'],
        :failover_logservers => [ '1.2.3.6', '1.2.3.7'],
        :interface           => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context 'when local priv user exists without ssh authorized keys' do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description => 'when local priv user exists without ssh authorized keys',
        :priv_user   =>  {
          :name     => 'simpadmin',
          :exists   => true, # ASSUMES user created by previous test remains
          :has_keys => false
        },
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context 'when local priv user exists with authorized keys' do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description => 'when local priv user exists with ssh authorized keys',
        :priv_user   =>  {
          :name     => 'vagrant',
          :exists   => true, # ASSUMES user already exists
          :has_keys => true  # ASSUMES authorized_key file exists
        },
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context "when do not want to ensure local priv user on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description => 'when do not want to ensure local priv user',
        :priv_user   => nil,
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  # simp_lite scenario is nearly identical to simp scenario, so only need
  # to test with defaults
  context "when simp_lite scenario using defaults on #{host}" do
    hosts.each do |host|
      include_examples 'remove SIMP omni environment', host, 'production'

      options = {
        :description => 'when simp_lite_scenario using defaults',
        :scenario    => 'simp_lite',
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end

  context 'when poss scenario' do
    context 'using defaults' do
      hosts.each do |host|
        include_examples 'remove SIMP omni environment', host, 'production'

        options = {
          :description => 'when poss scenario using defaults',
          :scenario    => 'poss',
          :interface   => host_interfaces[host].first
        }
        include_examples 'simp config operation', host, options
      end
    end

    context 'without LDAP but with SSSD' do
      hosts.each do |host|
        include_examples 'remove SIMP omni environment', host, 'production'

        options = {
          :description => 'with poss scenario without LDAP but with SSSD',
          :scenario    => 'poss',
          :ldap_server => false,
          :interface   => host_interfaces[host].first
        }
        include_examples 'simp config operation', host, options
      end
    end

    context 'without either LDAP or SSSD' do
      hosts.each do |host|
        include_examples 'remove SIMP omni environment', host, 'production'

        options = {
          :description => 'with poss scenario without either LDAP or SSSD',
          :scenario    => 'poss',
          :ldap_server => false,
          :sssd        => false,
          :interface   => host_interfaces[host].first
        }
        include_examples 'simp config operation', host, options
      end
    end
  end

  context 'with Puppet environment set by ENV' do
    hosts.each do |host|
      options = {
        :description => 'using SIMP_ENVIRONMENT',
        :puppet_env  => 'dev',
        :env_vars    => [ 'SIMP_ENVIRONMENT=dev' ],
        :interface   => host_interfaces[host].first
      }
      include_examples 'simp config operation', host, options
    end
  end
end
