require 'simp/cli/config/items/action/update_puppet_conf_action'
require 'simp/cli/config/items/data/simp_options_puppet_ca'
require 'simp/cli/config/items/data/simp_options_puppet_ca_port'
require 'simp/cli/config/items/data/simp_options_puppet_server'
require 'simp/cli/config/items/data/simp_options_fips'
require 'fileutils'

require_relative '../spec_helper'

describe Simp::Cli::Config::Item::UpdatePuppetConfAction do
  before :context do
    @ci             = Simp::Cli::Config::Item::UpdatePuppetConfAction.new
    @ci.start_time  = Time.new(2017, 1, 13, 11, 42, 3)
    @puppet_server  = 'puppet.nerd'
    @puppet_ca      = 'puppetca.nerd'
    @puppet_ca_port = '9999'
    @puppet_confdir = `puppet config print confdir 2>/dev/null`.strip
    @backup_file = File.join( @puppet_confdir, "puppet.conf.20170113T114203" )

    previous_items = {}
    s = Simp::Cli::Config::Item::SimpOptionsPuppetServer.new
    s.value = @puppet_server
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::SimpOptionsPuppetCA.new
    s.value = @puppet_ca
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::SimpOptionsPuppetCAPort.new
    s.value = @puppet_ca_port
    previous_items[ s.key ] = s

    @ci.config_items = previous_items
  end

  describe "#apply" do
    before :each do
      # remove any backup file from a previous test
      FileUtils.rm_f(@backup_file)

      # set initial state of puppet config
      `puppet config set digest_algorithm md5 2>/dev/null`
      `puppet config set keylength 128 2>/dev/null`
      `puppet config set server 127.0.0.1 2>/dev/null`
      `puppet config set ca_server 127.0.0.1 2>/dev/null`
      `puppet config set ca_port 1000 2>/dev/null`
      `puppet config set trusted_server_facts false 2>/dev/null`
    end

    context 'updates puppet configuration' do

      it 'backs up config file and configures server for FIPS mode' do
        item  = Simp::Cli::Config::Item::SimpOptionsFips.new
        item.value = true
        @ci.config_items[ item.key ] = item
        @ci.apply
        expect(@ci.applied_status).to eq :succeeded
        # Read in all settings at once because puppet cli can be slow
        puppet_settings = `puppet config print 2>/dev/null`
        expect( puppet_settings ).to match /digest_algorithm\s*=\s*sha256/
        expect( puppet_settings ).to match /keylength\s*=\s*2048/
        expect( puppet_settings ).to match /server\s*=\s*#{@puppet_server}/
        expect( puppet_settings ).to match /ca_server\s*=\s*#{@puppet_ca}/
        expect( puppet_settings ).to match /ca_port\s*=\s*#{@puppet_ca_port}/
        expect( puppet_settings ).to match /trusted_server_facts\s*=\s*true/
        expect( File ).to exist(@backup_file)
      end

      it 'backs up config file and configures server for non-FIPS mode' do
        item  = Simp::Cli::Config::Item::SimpOptionsFips.new
        item.value = false
        @ci.config_items[ item.key ] = item
        @ci.apply
        expect(@ci.applied_status).to eq :succeeded
        # Read in all settings at once because puppet cli can be slow
        puppet_settings = `puppet config print 2>/dev/null`
        expect( puppet_settings ).to match /digest_algorithm\s*=\s*sha256/
        expect( puppet_settings ).to match /keylength\s*=\s*4096/
        expect( puppet_settings ).to match /server\s*=\s*#{@puppet_server}/
        expect( puppet_settings ).to match /ca_server\s*=\s*#{@puppet_ca}/
        expect( puppet_settings ).to match /ca_port\s*=\s*#{@puppet_ca_port}/
        expect( puppet_settings ).to match /trusted_server_facts\s*=\s*true/
        expect( File ).to exist(@backup_file)
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      ci = Simp::Cli::Config::Item::UpdatePuppetConfAction.new
      ci.file = 'puppet.conf'
      expect(ci.apply_summary).to eq 'Update to Puppet settings in puppet.conf unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
