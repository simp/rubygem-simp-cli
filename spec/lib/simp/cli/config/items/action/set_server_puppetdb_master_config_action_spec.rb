require 'simp/cli/config/items/action/set_server_puppetdb_master_config_action'
require 'simp/cli/config/items/data/cli_network_hostname'
require 'simp/cli/config/items/data/puppetdb_master_config_puppetdb_port'
require 'simp/cli/config/items/data/puppetdb_master_config_puppetdb_server'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetServerPuppetDBMasterConfigAction do
  before :each do
    @ci        = Simp::Cli::Config::Item::SetServerPuppetDBMasterConfigAction.new
    @ci.silent = true
  end

  describe '#apply' do
    before :each do
      @tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
      @fqdn            = 'hostname.domain.tld'
      @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_yaml_file   = File.join( @tmp_dir, "#{@fqdn}.yaml" )
      @ci.dir          = @tmp_dir

      item             = Simp::Cli::Config::Item::CliNetworkHostname.new
      item.value       = @fqdn
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::PuppetDBMasterConfigPuppetDBServer.new
      item.value       = "puppet.test.local"
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::PuppetDBMasterConfigPuppetDBPort.new
      item.value       = 8139
      @ci.config_items[item.key] = item
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end

    it "adds puppetdb_port and puppetdb_server to <host>.yaml" do
      file = File.join( @files_dir,'puppet.your.domain.yaml')
      FileUtils.copy_file file, @tmp_yaml_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_puppetdb_config_added.yaml')
      expected_content = IO.read(expected)
      actual_content = IO.read(@tmp_yaml_file)
      expect( actual_content).to eq expected_content
    end

    it "replaces puppetdb_server and puppetdb_port in <host>.yaml" do
      @ci.config_items['puppetdb::master::config::puppetdb_server'].value = 'puppetdb.test.local'
      @ci.config_items['puppetdb::master::config::puppetdb_port'].value = 8239
      file = File.join(@files_dir, 'host_with_puppetdb_config_added.yaml')
      FileUtils.copy_file file, @tmp_yaml_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_puppetdb_config_replaced.yaml')
      expected_content = IO.read(expected)
      actual_content = IO.read(@tmp_yaml_file)
      expect( actual_content).to eq expected_content
    end

    it "fails when <host>.yaml does not exist" do
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

    it "fails when cli::network::hostname item does not exist" do
      @ci.config_items.delete('cli::network::hostname')
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerPuppetDBMasterConfigAction' +
        ' could not find cli::network::hostname' )
    end

    it "fails when puppetdb::master::config::puppetdb_server item does not exist" do
      @ci.config_items.delete('puppetdb::master::config::puppetdb_server')
      file = File.join( @files_dir,'puppet.your.domain.yaml')
      FileUtils.copy_file file, @tmp_yaml_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerPuppetDBMasterConfigAction' +
        ' could not find puppetdb::master::config::puppetdb_server' )
    end

    it "fails when puppetdb::master::config::puppetdb_port item does not exist" do
      @ci.config_items.delete('puppetdb::master::config::puppetdb_port')
      file = File.join( @files_dir,'puppet.your.domain.yaml')
      FileUtils.copy_file file, @tmp_yaml_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerPuppetDBMasterConfigAction' +
        ' could not find puppetdb::master::config::puppetdb_port' )
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq(
        'Setting of PuppetDB master server & port in SIMP server <host>.yaml unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
