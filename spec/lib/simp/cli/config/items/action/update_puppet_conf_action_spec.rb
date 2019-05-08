require 'simp/cli/config/items/action/update_puppet_conf_action'
require 'fileutils'

require_relative '../spec_helper'

describe Simp::Cli::Config::Item::UpdatePuppetConfAction do
  before :each do
    @file_dir = File.expand_path( 'files',  File.dirname( __FILE__ ) )

    @tmp_dir = Dir.mktmpdir( File.basename(__FILE__))
    @puppet_conf = File.join(@tmp_dir, 'puppet.conf')

    @puppet_env_info = {
      :puppet_config     => {
        'modulepath' => '/does/not/matter',
        'config'     => @puppet_conf
      },
    }

    FileUtils.cp(File.join(@file_dir, 'puppet.conf'), @puppet_conf)

    @ci             = Simp::Cli::Config::Item::UpdatePuppetConfAction.new(@puppet_env_info)
    @ci.start_time  = Time.new(2017, 1, 13, 11, 42, 3)

    @puppet_server  = 'puppet.nerd'
    @puppet_ca      = 'puppetca.nerd'
    @puppet_ca_port = '9999'

    previous_items = {}
    s = Simp::Cli::Config::Item::SimpOptionsPuppetServer.new(@puppet_env_info)
    s.value = @puppet_server
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::SimpOptionsPuppetCA.new(@puppet_env_info)
    s.value = @puppet_ca
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::SimpOptionsPuppetCAPort.new(@puppet_env_info)
    s.value = @puppet_ca_port
    previous_items[ s.key ] = s

    @ci.config_items = previous_items

    @backup_conf = @puppet_conf + '.' + @ci.start_time.strftime('%Y%m%dT%H%M%S')
  end

  describe "#apply" do
    context 'updates puppet configuration' do
      before(:each) do
        allow(@ci).to receive(:execute).with(any_args).and_call_original
        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set server #{@puppet_server})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_server #{@puppet_ca})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_port #{@puppet_ca_port})).and_return(true)

        @fips_item = Simp::Cli::Config::Item::SimpOptionsFips.new(@puppet_env_info)
        @ci.config_items[ @fips_item.key ] = @fips_item
      end

      it 'backs up config file and configures server for FIPS mode' do
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 2048)).and_return(true)
        @fips_item.value = true

        @ci.apply

        expect(@ci.applied_status).to eq :succeeded
        expected_content = File.read( File.join( @file_dir, 'puppet.conf.updated' ) )
        actual_content = File.read( @puppet_conf )
        expect( actual_content ).to eq expected_content

        expect( File ).to exist( @backup_conf )
        expected_backup_content = File.read( File.join( @file_dir, 'puppet.conf') )
        actual_backup_content = File.read( @backup_conf )
        expect( actual_backup_content ).to eq expected_backup_content
      end

      it 'backs up config file and configures server for non-FIPS mode' do
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 4096)).and_return(true)
        @fips_item.value = false

        @ci.apply

        expect(@ci.applied_status).to eq :succeeded
        expected_content = File.read( File.join( @file_dir, 'puppet.conf.updated' ) )
        actual_content = File.read( @puppet_conf )
        expect( actual_content ).to eq expected_content

        expect( File ).to exist( @backup_conf )
        expected_backup_content = File.read( File.join( @file_dir, 'puppet.conf') )
        actual_backup_content = File.read( @backup_conf )
        expect( actual_backup_content ).to eq expected_backup_content
      end
    end

    context 'puppet config failures' do
      before(:each) do
        allow(@ci).to receive(:execute).with(any_args).and_call_original
        fips_item = Simp::Cli::Config::Item::SimpOptionsFips.new(@puppet_env_info)
        fips_item.value = false
        @ci.config_items[ fips_item.key ] = fips_item
      end

      it 'returns failed status when the puppet set digest_algorithm fails' do
        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(false)

        @ci.apply

        expect(@ci.applied_status).to eq :failed
      end

      it 'returns failed status when the puppet set keylength fails' do
        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 4096)).and_return(false)

        @ci.apply

        expect(@ci.applied_status).to eq :failed
      end

      it 'returns failed status when the puppet set server fails' do
        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 4096)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set server #{@puppet_server})).and_return(false)

        @ci.apply

        expect(@ci.applied_status).to eq :failed
      end

      it 'returns failed status when the puppet set ca_server fails' do
        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 4096)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set server #{@puppet_server})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_server #{@puppet_ca})).and_return(false)

        @ci.apply

        expect(@ci.applied_status).to eq :failed
      end

      it 'returns failed status when the puppet set ca_port fails' do
        expect(@ci).to receive(:execute).with(%(puppet config set digest_algorithm sha256)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set keylength 4096)).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set server #{@puppet_server})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_server #{@puppet_ca})).and_return(true)
        expect(@ci).to receive(:execute).with(%(puppet config set ca_port #{@puppet_ca_port})).and_return(false)

        @ci.apply

        expect(@ci.applied_status).to eq :failed
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      expect(@ci.apply_summary).to eq "Update to Puppet settings in #{@puppet_conf} unattempted"
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
