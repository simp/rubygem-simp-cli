require 'simp/cli/config/items/action/set_up_puppet_autosign_action'
require 'simp/cli/config/items/data/cli_network_hostname'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetUpPuppetAutosignAction do
  before :each do
    @file_dir  = File.expand_path( 'files',  File.dirname( __FILE__ ) )
    @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__) )
    allow(::Utils).to receive(:puppet_info).and_return( {
      :config => {
        'codedir' => @tmp_dir,
        'confdir' => @tmp_dir
      },
      :environment_path => File.join(@tmp_dir, 'environments'),
      :simp_environment_path => File.join(@tmp_dir, 'environments', 'simp'),
      :fake_ca_path => File.join(@tmp_dir, 'environments', 'simp', 'FakeCA')
    } )
    @ci        = Simp::Cli::Config::Item::SetUpPuppetAutosignAction.new
    @ci.silent = true
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)

    # add hostname to ConfigItems
    item             = Simp::Cli::Config::Item::CliNetworkHostname.new
    item.value       = 'puppet.domain.tld'
    @ci.config_items[item.key] = item
  end

  describe "#apply" do
    it 'backs up existing autosign.conf and then replaces any comments with instructions' do
      # copy file from files to tmp
      FileUtils.cp File.join( @file_dir, 'autosign.conf.used'), @tmp_dir
      @ci.file   = File.join( @tmp_dir, 'autosign.conf.used' )
      @ci.apply
      expected_content = File.read( File.join( @file_dir, 'autosign.conf.used_updated' ) )
      actual_content = File.read( @ci.file )
      expect( actual_content ).to eq expected_content

      backup_file = "#{@ci.file}.20170113T114203"
      expect( File ).to exist( backup_file )
      expected_backup_content = File.read( File.join( @file_dir, 'autosign.conf.used') )
      actual_backup_content = File.read( backup_file) 
      expect( actual_backup_content ).to eq expected_backup_content
    end

    it 'handles a newly-bootstrapped autosign.conf' do
      # copy file from files to tmp
      FileUtils.cp File.join( @file_dir, 'autosign.conf.new'), @tmp_dir
      @ci.file   = File.join( @tmp_dir, 'autosign.conf.new' )
      @ci.apply
      actual_content = File.read( @ci.file )
      expected_content = File.read( File.join( @file_dir, 'autosign.conf.new_updated' ) )
      expect( actual_content ).to eq expected_content
    end

    it 'handles an empty autosign.conf' do
      FileUtils.touch File.join( @tmp_dir, 'autosign.conf.empty' )
      @ci.file   = File.join( @tmp_dir, 'autosign.conf.empty' )
      @ci.apply
      actual_content = File.read( @ci.file )
      expected_content = File.read( File.join( @file_dir, 'autosign.conf.new_updated' ) )
      expect( actual_content ).to eq expected_content
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq "Setup of autosign in #{File.join(@tmp_dir, 'autosign.conf')} unattempted"
    end
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

