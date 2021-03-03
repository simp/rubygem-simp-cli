require 'simp/cli/config/items/action/set_server_ldap_server_config_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetServerLdapServerConfigAction do
  before :each do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    @tmp_dir   = Dir.mktmpdir( File.basename(__FILE__) )
    @hosts_dir = File.join(@tmp_dir, 'hosts')
    FileUtils.mkdir(@hosts_dir)

    @fqdn = 'hostname.domain.tld'
    @host_file = File.join( @hosts_dir, "#{@fqdn}.yaml" )

    @puppet_env_info = {
      :puppet_config      => { 'modulepath' => '/does/not/matter' },
      :puppet_env_datadir => @tmp_dir
    }

    @ci        = Simp::Cli::Config::Item::SetServerLdapServerConfigAction.new(@puppet_env_info)
    @ci.silent = true
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#apply' do
    before :each do
      item       = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
      item.value = @fqdn
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpOpenldapServerConfRootpw.new(@puppet_env_info)
      item.value = '{SSHA}deadbeefDEADBEEFdeadbeefDEADBEEF'
      @ci.config_items[item.key] = item
    end

    it 'adds LDAP server config to <host>.yaml' do
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_ldap_server_config_added.yaml')
      expect( IO.read(@host_file) ).to eq IO.read(expected)
    end

    it 'replaces LDAP server config <host>.yaml' do
      @ci.config_items['simp_openldap::server::conf::rootpw'].value = '{SSHA}UJEQJzeoFmKAJX57NBNuqerTXndGx/lL'
      file = File.join(@files_dir, 'host_with_ldap_server_config_added.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_ldap_server_config_replaced.yaml')
      expect( IO.read(@host_file) ).to eq IO.read(expected)
    end

    it 'fails when <host>.yaml does not exist' do
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

    it 'fails when cli::network::hostname item does not exist' do
      @ci.config_items.delete('cli::network::hostname')
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerLdapServerConfigAction' +
        ' could not find cli::network::hostname' )
    end

    it 'fails when simp_openldap::server::conf::rootpw item does not exist' do
      @ci.config_items.delete('simp_openldap::server::conf::rootpw')
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerLdapServerConfigAction' +
        ' could not find simp_openldap::server::conf::rootpw' )
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect( @ci.apply_summary ).to eq(
        'Setting of LDAP Root password hash in SIMP server <host>.yaml unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
