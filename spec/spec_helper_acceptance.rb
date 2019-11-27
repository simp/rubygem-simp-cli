require 'beaker-rspec'
require_relative 'acceptance/shared_examples'

require 'tmpdir'
require 'yaml'
require 'simp/beaker_helpers'
include Simp::BeakerHelpers

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
    # Install git, it's a dependency for inspec profiles
    # Found this when experiencing https://github.com/chef/inspec/issues/1270
    install_package(host, 'git')
  end
end


RSpec.configure do |c|
  # ensure that environment OS is ready on each host
  fix_errata_on hosts

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    begin
      # Copy over modules and dependencies from spec/fixtures/modules.
      # Tests will move to correct locations and let puppetserver handle plugin-sync.
      copy_fixture_modules_to( hosts, { :pluginsync => false } )
    rescue StandardError, ScriptError => e
      if ENV['PRY']
        require 'pry'; binding.pry
      else
        raise e
      end
    end
  end
end
