require 'simp/cli/config/items/action/add_ldap_server_class_to_server_action'
require 'simp/cli/config/items/data/cli_network_hostname'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::AddLdapServerClassToServerAction do
  before :each do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    @tmp_dir   = Dir.mktmpdir( File.basename(__FILE__) )
    @hosts_dir = File.join(@tmp_dir, 'hosts')
    FileUtils.mkdir(@hosts_dir)

    @fqdn = 'hostname.domain.tld'
    @host_file = File.join( @hosts_dir, "#{@fqdn}.yaml" )
    allow(Simp::Cli::Utils).to receive(:simp_env_datadir).and_return(@tmp_dir)

    @ci        = Simp::Cli::Config::Item::AddLdapServerClassToServerAction.new
    @ci.silent = true
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#apply' do

    context 'with a valid fqdn' do
      before :each do
        item       = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value = @fqdn
        @ci.config_items[item.key] = item
      end

      it 'adds simp::server::ldap class to <host>.yaml' do
        file = File.join(@files_dir, 'puppet.your.domain.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_simp_server_ldap.yaml')

        expect( FileUtils.compare_file(expected, @host_file) ).to be true
      end

      it 'ensures only one simp::server::ldap class exists in <host>.yaml' do
        file = File.join(@files_dir, 'host_with_simp_server_ldap.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        expect( FileUtils.compare_file(file, @host_file) ).to be true
      end

      it 'fails when <host>.yaml does not exist' do
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect( @ci.apply_summary ).to eq 'Addition of simp::server::ldap to SIMP server <host>.yaml class list unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
