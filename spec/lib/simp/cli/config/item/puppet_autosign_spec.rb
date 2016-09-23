require 'simp/cli/config/item/puppet_autosign'
require 'simp/cli/config/item/hostname'
require 'rspec/its'
require_relative 'spec_helper'

describe Simp::Cli::Config::Item::PuppetAutosign do
  before :each do
    @file_dir  = File.expand_path( 'files',  File.dirname( __FILE__ ) )
    @tmp_dir   = Dir.mktmpdir(File.basename(__FILE__) )
    @ci        = Simp::Cli::Config::Item::PuppetAutosign.new
    @ci.silent = true

    # add hostname to ConfigItems
    item             = Simp::Cli::Config::Item::Hostname.new
    item.value       = 'puppet.domain.tld'
    @ci.config_items[item.key] = item
  end

  describe "#apply" do
    it 'persists an existing autosign.conf' do
      # copy file from files to tmp
      FileUtils.cp File.join( @file_dir, 'autosign.conf.used'), @tmp_dir
      @ci.file   = File.join( @tmp_dir, 'autosign.conf.used' )
      @ci.apply
      lines = File.readlines( @ci.file ).join( "\n" )
      expect( lines ).to match(%r{^puppet.fake.domain\n\s*server1.fake.domain\n\s*server2.fake.domain$})
    end

    it 'handles a newly-bootstrapped autosign.conf' do
      # copy file from files to tmp
      FileUtils.cp File.join( @file_dir, 'autosign.conf.new'), @tmp_dir
      @ci.file   = File.join( @tmp_dir, 'autosign.conf.new' )
      @ci.apply
      lines = File.readlines( @ci.file ).join( "\n" )
      expect( lines ).to match(%r{^puppet.domain.tld$})
    end

    it 'handles an empty autosign.conf' do
      FileUtils.touch File.join( @tmp_dir, 'autosign.conf.empty' )
      @ci.file   = File.join( @tmp_dir, 'autosign.conf.empty' )
      @ci.apply
      lines = File.readlines( @ci.file ).join( "\n" )
      expect( lines ).to match(%r{^puppet.domain.tld$})
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq 'Setup of autosign in /etc/puppet/autosign.conf unattempted'
    end
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

