require 'simp/cli/config/items/action/add_simp_yum_repo_internet_simp_server_class_to_server_action'
require 'simp/cli/config/items/data/cli_network_hostname'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::AddSimpYumRepoInternetSimpServerClassToServerAction do
  before :each do
    @ci        = Simp::Cli::Config::Item::AddSimpYumRepoInternetSimpServerClassToServerAction.new
    @ci.silent = true
  end

  describe "#apply" do
    before :context do
      @tmp_dir         = Dir.mktmpdir( File.basename(__FILE__) )
    end

    context "with a valid fqdn" do
      before :each do
        @fqdn            = 'hostname.domain.tld'
        @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
        @tmp_file        = File.join( @tmp_dir, "#{@fqdn}.yaml" )
        @ci.dir          = @tmp_dir

        item             = Simp::Cli::Config::Item::CliNetworkHostname.new
        item.value       = @fqdn
        @ci.config_items[item.key] = item
        @new_file        = File.join( @tmp_dir, "#{@fqdn}.yaml" )

        FileUtils.mkdir_p   @tmp_dir
      end

      after :each do
        FileUtils.remove_entry_secure @tmp_dir
      end

      it "adds simp::yum::repo::internet_simp_server class to <host>.yaml" do
        file = File.join( @files_dir,'puppet.your.domain.yaml')
        FileUtils.copy_file file, @tmp_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded
        expected = IO.read(File.join(@files_dir, 'host_with_internet_simp_server.yaml'))
        actual = IO.read(@tmp_file)

        expect( actual ).to eq expected
      end

      it "ensures only one simp::yum::repo::internet_simp_server class exists in <host>.yaml" do
        file = File.join(@files_dir, 'host_with_internet_simp_server.yaml')
        FileUtils.copy_file file, @tmp_file

        @ci.apply
        expect( @ci.applied_status ).to eq :succeeded

        expected = IO.read(file)
        actual = IO.read(@tmp_file)
        expect( actual ).to eq expected
      end

      it "fails when <host>.yaml does not exist" do
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Addition of simp::yum::repo::internet_simp_server to SIMP server <host>.yaml class list unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
