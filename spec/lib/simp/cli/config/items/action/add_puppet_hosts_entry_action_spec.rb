require 'simp/cli/config/items/action/add_puppet_hosts_entry_action'
require 'simp/cli/config/items/data/cli_puppet_server_ip'
require 'simp/cli/config/items/data/simp_options_puppet_server'
require 'rspec/its'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::AddPuppetHostsEntryAction do
  before :all do
    @ci        = Simp::Cli::Config::Item::AddPuppetHostsEntryAction.new
    @ci.silent = true   # turn off command line summary on stdout
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)

    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @tmp_dir   = Dir.mktmpdir( File.basename( __FILE__ ) )
  end

  describe '#apply' do
    before :context do
      @tmp_file        = File.join( @tmp_dir, 'test__hosts' )
      @file            = File.join( @files_dir,'hosts')
      @ci.file         = @tmp_file

      item             = Simp::Cli::Config::Item::CliPuppetServerIP.new
      item.value       = '1.2.3.4'
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::SimpOptionsPuppetServer.new
      item.value       = 'puppet.domain.tld'
      @ci.config_items[item.key] = item
    end

    context 'with a fresh hosts file' do
      before :context do
        FileUtils.mkdir_p   @tmp_dir
        FileUtils.copy_file @file, @tmp_file

        @ci.apply
        @content = File.read(@tmp_file)
      end

      it 'backs up the existing hosts file' do
        backup_file = "#{@tmp_file}.20170113T114203"
        expect( File.exist?(backup_file) ).to eq true
      end

      it 'configures hosts with the correct values' do
        expect( @content ).to match(%r{\bpuppet.domain.tld\b})
      end

      it 'removes comments' do
        expect( @content ).not_to match(%r{# some comment})
      end

      it 'retains other host entries' do
        expect( @content ).to match(%r{1.2.3.4 dev1.test.local})
      end

      it 'reports success' do
        expect( @ci.applied_status ).to eq :succeeded
      end

      after :context do
        FileUtils.remove_entry_secure @tmp_dir
      end
    end


    context 'with an existing hosts file' do
      before :context do
        @file = File.join( @files_dir,'hosts.old_puppet_entry')
        FileUtils.mkdir_p   @tmp_dir
        FileUtils.copy_file @file, @tmp_file

        @ci.apply
      end

      it 'configures hosts with the correct values' do
        content = File.read( @tmp_file )
        expect( content ).to match(%r{\bpuppet.domain.tld\b})
      end

      it 'replaces puppet host/aliases with the correct values' do
        content = File.read( @tmp_file )
        expect( content ).to_not match(%r{\bpuppet.example.com\b})
      end

      it 'reports success' do
        expect( @ci.applied_status ).to eq :succeeded
      end

      after :context do
        FileUtils.remove_entry_secure @tmp_dir
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      ci        = Simp::Cli::Config::Item::AddPuppetHostsEntryAction.new
      ci.file = 'hosts'
      expect(ci.apply_summary).to eq 'Update to hosts to ensure puppet server entries exist unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

