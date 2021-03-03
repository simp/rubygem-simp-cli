require 'simp/cli/config/items/action/allow_local_priv_user_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::AllowLocalPrivUserAction do
  def build_config_items(fqdn, local_priv_user, puppet_env_info)
    config_items = {}
    item = Simp::Cli::Config::Item::CliNetworkHostname.new(puppet_env_info)
    item.value = fqdn
    config_items[item.key] = item

    item = Simp::Cli::Config::Item::CliLocalPrivUser.new(puppet_env_info)
    item.value = local_priv_user
    config_items[item.key] = item

    item = Simp::Cli::Config::Item::CliLocalPrivUserExists.new(puppet_env_info)
    item.value = true
    config_items[item.key] = item

    item = Simp::Cli::Config::Item::CliLocalPrivUserHasSshAuthorizedKeys.new(puppet_env_info)
    item.value = true
    config_items[item.key] = item

    item = Simp::Cli::Config::Item::PamAccessUsers.new(puppet_env_info)
    item.config_items = config_items
    item.value = item.get_recommended_value
    config_items[item.key] = item

    item = Simp::Cli::Config::Item::SelinuxLoginResources.new(puppet_env_info)
    item.config_items = config_items
    item.value = item.get_recommended_value
    config_items[item.key] = item

    item = Simp::Cli::Config::Item::SudoUserSpecifications.new(puppet_env_info)
    item.config_items = config_items
    item.value = item.get_recommended_value
    config_items[item.key] = item
    config_items
  end

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

    @ci        = Simp::Cli::Config::Item::AllowLocalPrivUserAction.new(@puppet_env_info)
    @ci.silent = true
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#apply' do
    it 'adds ssh+sudo config to <host>.yaml' do
      @ci.config_items = build_config_items(@fqdn, 'local_admin', @puppet_env_info)

      file = File.join(@files_dir, 'puppet.your.domain.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_allow_local_priv_user.yaml')
      expect( IO.read(@host_file) ).to eq IO.read(expected)
    end

    it 'merges with existing ssh+sudo config in <host>.yaml' do
      @ci.config_items = build_config_items(@fqdn, 'new_local_admin', @puppet_env_info)

      file = File.join(@files_dir, 'host_with_allow_local_priv_user.yaml')
      FileUtils.copy_file file, @host_file

      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected = File.join(@files_dir, 'host_with_allow_local_priv_user_merged.yaml')
      expect( IO.read(@host_file) ).to eq IO.read(expected)
    end

    it 'fails when <host>.yaml does not exist' do
      @ci.config_items = build_config_items(@fqdn, 'local_admin', @puppet_env_info)

      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

    it 'fails when cli::network::hostname item does not exist' do
      @ci.config_items = build_config_items(@fqdn, 'local_admin', @puppet_env_info)
      @ci.config_items.delete('cli::network::hostname')
      expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::AllowLocalPrivUserAction' +
        ' could not find cli::network::hostname' )
    end

   [
     'pam::access::users',
     'selinux::login_resources',
     'sudo::user_specifications'
    ].each do |item_key|
      it "fails when #{item_key} item does not exist" do
        @ci.config_items = build_config_items(@fqdn, 'local_admin', @puppet_env_info)
        @ci.config_items.delete(item_key)
        file = File.join(@files_dir, 'puppet.your.domain.yaml')
        FileUtils.copy_file file, @host_file
        expect{ @ci.apply }.to raise_error( Simp::Cli::Config::MissingItemError,
          'Internal error: Simp::Cli::Config::Item::AllowLocalPrivUserAction' +
          " could not find #{item_key}" )
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      @ci.config_items = build_config_items(@fqdn, 'local_admin', @puppet_env_info)
      expect( @ci.apply_summary ).to eq(
        "Configuring ssh & sudo for local user 'local_admin' in SIMP server <host>.yaml unattempted")
    end

    it 'fails when cli::local_priv_user item does not exist' do
      @ci.config_items = build_config_items(@fqdn, 'local_admin', @puppet_env_info)
      @ci.config_items.delete('cli::local_priv_user')
      expect{ @ci.apply_summary }.to raise_error( Simp::Cli::Config::MissingItemError,
        'Internal error: Simp::Cli::Config::Item::AllowLocalPrivUserAction' +
        ' could not find cli::local_priv_user' )
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
