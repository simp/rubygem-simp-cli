require 'simp/cli/config/items/action/set_server_grub_config_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetServerGrubConfigAction do
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

    @ci        = Simp::Cli::Config::Item::SetServerGrubConfigAction.new(@puppet_env_info)
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

      item       = Simp::Cli::Config::Item::SimpGrubPassword.new(@puppet_env_info)
      item.value = 'grub.pbkdf2.sha512.10000.D0CCB6553D29D3C25284D4FB8967ABF87E69ABD415F3E71668B7ADAD81FCBF47471C3CC45E48203754AD79A76BDBA07392124EAA53FE837CEE99CFE45E7881B0.939C311509D96842FD8E1CA2EE8F24E91084619730A7A1EDC7E76D00955DEA3B3BB78CD8B7A54FEAAE37FE5C79A108AF2BF6FCD1A5EEABDED3ABABBA3FC0398A'
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpGrubAdmin.new(@puppet_env_info)
      item.value = 'admin'
      @ci.config_items[item.key] = item
    end

    it 'adds grub config to <host>.yaml' do
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_grub_config_added.yaml')
      expect( IO.read(@host_file) ).to eq IO.read(expected)
    end

    it 'replaces GRUB server config <host>.yaml' do
      @ci.config_items['simp_grub::password'].value = 'grub.pbkdf2.sha512.10000.DEADBEEF0009D3C25284D4FB8967ABF87E69ABD415F3E71668B7ADAD81FCBF47471C3CC45E48203754AD79A76BDBA07392124EAA53FE837CEE99CFE45E7881B0.939C311509D96842FD8E1CA2EE8F24E91084619730A7A1EDC7E76D00955DEA3B3BB78CD8B7A54FEAAE37FE5C79A108AF2BF6FCD1A5EEABDED3ABABBA3FC0398A'
      file = File.join(@files_dir, 'host_with_grub_config_added.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_grub_config_replaced.yaml')
      expect( IO.read(@host_file) ).to eq IO.read(expected)
    end

    it 'fails when <host>.yaml does not exist' do
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

    it 'fails when cli::network::hostname item does not exist' do
      @ci.config_items.delete('cli::network::hostname')
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerGrubConfigAction' +
        ' could not find cli::network::hostname' )
    end

    it 'fails when simp_grub::password item does not exist' do
      @ci.config_items.delete('simp_grub::password')
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerGrubConfigAction' +
        ' could not find simp_grub::password' )
    end

    it 'fails when simp_grub::admin item does not exist' do
      @ci.config_items.delete('simp_grub::admin')
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::SetServerGrubConfigAction' +
        ' could not find simp_grub::admin' )
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect( @ci.apply_summary ).to eq(
        'Setting of GRUB password hash in SIMP server <host>.yaml unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
