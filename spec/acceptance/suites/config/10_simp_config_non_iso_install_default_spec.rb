require 'spec_helper_acceptance'
require 'yaml'

test_name 'simp config with defaults for non-ISO'

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
describe 'simp config with defaults for non-ISO install' do
  hosts.each do |host|
    context "using defaults on #{host}" do
      interfaces = fact_on(host, 'interfaces').split(',').delete_if { |x| x == 'lo' }
      options = {
        :description => 'using defaults',
        :interface   => interfaces.first
      }
      include_examples 'simp config operation', host, options
    end
  end
end
