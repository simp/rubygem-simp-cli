require 'simp/cli/config/items/action/set_up_puppet_autosign_action'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::SetUpPuppetAutosignAction do
  before :each do
    @file_dir  = File.expand_path( 'files',  File.dirname( __FILE__ ) )
    @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__) )
    @autosign_conf = File.join( @tmp_dir, 'autosign.conf' )

    puppet_env_info = {
      :puppet_config => {
        'autosign'   => @autosign_conf,
        'modulepath' => '/does/not/matter'
      },
      :puppet_group  => `groups`.split[0]
    }

    @ci        = Simp::Cli::Config::Item::SetUpPuppetAutosignAction.new(puppet_env_info)
    @ci.silent = true
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)

    # add hostname to ConfigItems
    item             = Simp::Cli::Config::Item::CliNetworkHostname.new(puppet_env_info)
    item.value       = 'puppet.domain.tld'
    @ci.config_items[item.key] = item
  end

  describe '#apply' do
    it 'backs up existing autosign.conf and then replaces any comments with instructions' do
      # copy file from files to tmp
      FileUtils.cp File.join( @file_dir, 'autosign.conf.used'), @autosign_conf
      FileUtils.chmod( 0775, @autosign_conf )
      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      expected_content = File.read( File.join( @file_dir, 'autosign.conf.used_updated' ) )
      actual_content = File.read( @autosign_conf )
      expect( actual_content ).to eq expected_content
      expect( File.stat( @autosign_conf ).mode & 0777).to eq 0640

      backup_file = "#{@autosign_conf}.20170113T114203"
      expect( File ).to exist( backup_file )
      expected_backup_content = File.read( File.join( @file_dir, 'autosign.conf.used') )
      actual_backup_content = File.read( backup_file )
      expect( actual_backup_content ).to eq expected_backup_content
    end

    it 'handles a newly-bootstrapped autosign.conf' do
      FileUtils.cp File.join( @file_dir, 'autosign.conf.new'), @autosign_conf
      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      actual_content = File.read( @autosign_conf )
      expected_content = File.read( File.join( @file_dir, 'autosign.conf.new_updated' ) )
      expect( actual_content ).to eq expected_content
      expect( File.stat( @autosign_conf ).mode & 0777).to eq 0640
    end

    it 'handles an empty autosign.conf' do
      FileUtils.touch @autosign_conf
      @ci.apply
      expect( @ci.applied_status ).to eq :succeeded
      actual_content = File.read( @autosign_conf )
      expected_content = File.read( File.join( @file_dir, 'autosign.conf.new_updated' ) )
      expect( actual_content ).to eq expected_content
    end

    it 'fails if puppet group does not exist' do
      allow(FileUtils).to receive(:chown).with(nil, `groups`.split[0], @autosign_conf).and_raise( ArgumentError )

      FileUtils.touch @autosign_conf
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq "Setup of autosign in #{File.join(@tmp_dir, 'autosign.conf')} unattempted"
    end
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

