require 'simp/cli/config/items/action/add_simp_yum_repo_internet_simp_server_class_to_server_action'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::AddSimpYumRepoInternetSimpServerClassToServerAction do
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

    @ci        = Simp::Cli::Config::Item::AddSimpYumRepoInternetSimpServerClassToServerAction.new(@puppet_env_info)
    @ci.silent = true
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#apply' do

    context 'with a valid fqdn' do
      before :each do
        item       = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
        item.value = @fqdn
        @ci.config_items[item.key] = item
      end

      it 'adds simp::yum::repo::internet_simp_server class to <host>.yaml' do
        file = File.join(@files_dir, 'puppet.your.domain.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        expected = IO.read(File.join(@files_dir, 'host_with_internet_simp_server.yaml'))
        actual = IO.read(@host_file)

        expect( actual ).to eq expected
      end

      it 'ensures only one simp::yum::repo::internet_simp_server class exists in <host>.yaml' do
        file = File.join(@files_dir, 'host_with_internet_simp_server.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded

        expected = IO.read(file)
        actual = IO.read(@host_file)
        expect( actual ).to eq expected
      end

      it 'fails when <host>.yaml does not exist' do
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect( @ci.apply_summary ).to eq 'Addition of simp::yum::repo::internet_simp_server to SIMP server <host>.yaml class list unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
