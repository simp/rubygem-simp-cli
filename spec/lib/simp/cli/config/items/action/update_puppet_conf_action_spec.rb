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
    @ci.file        = 'test'

    @puppet_server  = 'puppet.nerd'
    @puppet_ca      = 'puppetca.nerd'
    @puppet_ca_port = '9999'

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
    context 'updates puppet configuration' do
      before(:each) do
        @item = Simp::Cli::Config::Item::SimpOptionsFips.new

        backup_file = @ci.file + '.' + @ci.start_time.strftime('%Y%m%dT%H%M%S')
        expect(FileUtils).to receive(:cp).with(@ci.file, backup_file)

        current_dir_stat = File.stat(Dir.pwd)
        expect(File).to receive(:stat).with(@ci.file).and_return(current_dir_stat)
        expect(File).to receive(:chown).with(nil, current_dir_stat.gid, backup_file)

        expect(@ci).to receive(:execute).with(%(sed -i '/^\s*server.*/d' #{@ci.file}))
        expect(@ci).to receive(:execute).with(%(sed -i '/.*trusted_node_data.*/d' #{@ci.file}))
        expect(@ci).to receive(:execute).with(%(sed -i '/.*digest_algorithm.*/d' #{@ci.file}))
        expect(@ci).to receive(:execute).with(%(sed -i '/.*stringify_facts.*/d' #{@ci.file}))
        unless Puppet.version.split('.').first <= '4'
          expect(@ci).to receive(:execute).with(%(sed -i '/.*trusted_server_facts.*/d' #{@ci.file}))
        end

        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set server #{@puppet_server})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_server #{@puppet_ca})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_port #{@puppet_ca_port})).and_return(true)

        @ci.config_items[ @item.key ] = @item
      end

      it 'backs up config file and configures server for FIPS mode' do
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 2048)).and_return(true)

        @item.value = true

        @ci.apply

        expect(@ci.applied_status).to eq :succeeded
      end

      it 'backs up config file and configures server for non-FIPS mode' do
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 4096)).and_return(true)

        @item.value = false

        @ci.apply

        expect(@ci.applied_status).to eq :succeeded
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
