require 'simp/cli/config/items/action/disallow_simp_user_action'
require 'fileutils'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::DisallowSimpUserAction do
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

    @ci        = Simp::Cli::Config::Item::DisallowSimpUserAction.new(@puppet_env_info)
    @ci.silent = true
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  context '#apply' do
    before :each do
      item       = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
      item.value = @fqdn
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpServerAllowSimpUser.new(@puppet_env_info)
      item.value = false
      @ci.config_items[item.key] = item
    end

    it 'adds simp::server::allow_simp_user to <host>.yaml' do
      file = File.join(@files_dir, 'host_without_allow_simp_user.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_allow_simp_user_added.yaml')
      expected_content = IO.read(expected)
      actual_content = IO.read(@host_file)
      expect( actual_content ).to eq expected_content
    end

    it 'replaces simp::server::allow_simp_user in <host>.yaml' do
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_allow_simp_user_replaced.yaml')
      expected_content = IO.read(expected)
      actual_content = IO.read(@host_file)
      expect( actual_content ).to eq expected_content
    end

    it 'fails when <host>.yaml does not exist' do
      @ci.apply
      expect( @ci.applied_status ).to eq(:failed)
    end

    it 'fails when cli::network::hostname item does not exist' do
      @ci.config_items.delete('cli::network::hostname')
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::DisallowSimpUserAction' +
        ' could not find cli::network::hostname' )
    end

    it 'fails when simp::server::allow_simp_user item does not exist' do
      @ci.config_items.delete('simp::server::allow_simp_user')
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::DisallowSimpUserAction' +
        ' could not find simp::server::allow_simp_user' )
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect( @ci.apply_summary ).to eq(
        "Disable of inapplicable user config in SIMP server <host>.yaml unattempted")
    end

  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
