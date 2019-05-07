require 'simp/cli/config/items/action/disable_server_local_os_and_simp_yum_repos_action'
require 'fileutils'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::DisableServerLocalOsAndSimpYumReposAction do
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

    @ci        = Simp::Cli::Config::Item::DisableServerLocalOsAndSimpYumReposAction.new(@puppet_env_info)
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

      item       = Simp::Cli::Config::Item::SimpYumRepoLocalOsUpdatesEnableRepo.new(@puppet_env_info)
      item.value = false
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpYumRepoLocalSimpEnableRepo.new(@puppet_env_info)
      item.value = false
      @ci.config_items[item.key] = item
    end

    it 'adds local_os_updates::enable_repo and local_simp::enable_repo to <host>.yaml' do
      file = File.join(@files_dir, 'host_without_enable_repos.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_enable_repos_added.yaml')
      expected_content = IO.read(expected)
      actual_content = IO.read(@host_file)
      expect( actual_content ).to eq expected_content
    end

    it 'replaces local_os_updates::enable_repo and local_simp::enable_repo in <host>.yaml' do
      file = File.join(@files_dir, 'host_with_enable_repos_true.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_enable_repos_replaced.yaml')
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
        'Internal error: Simp::Cli::Config::Item::DisableServerLocalOsAndSimpYumReposAction' +
        ' could not find cli::network::hostname' )
    end

    it 'fails when simp::yum::rep::local_os_updates::enable_os_repo item does not exist' do
      @ci.config_items.delete('simp::yum::repo::local_os_updates::enable_repo')
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::DisableServerLocalOsAndSimpYumReposAction' +
        ' could not find simp::yum::repo::local_os_updates::enable_repo' )
    end

    it 'fails when simp::yum::repo::local_simp::enable_repo item does not exist' do
      @ci.config_items.delete('simp::yum::repo::local_simp::enable_repo')
      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::DisableServerLocalOsAndSimpYumReposAction' +
        ' could not find simp::yum::repo::local_simp::enable_repo' )
    end

    it_behaves_like "an Item that doesn't output YAML"
    it_behaves_like 'a child of Simp::Cli::Config::Item'
  end
end
