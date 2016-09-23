require 'simp/cli/config/item/puppet_conf'
require 'simp/cli/config/item/puppet_ca'
require 'simp/cli/config/item/puppet_ca_port'
require 'simp/cli/config/item/puppet_server'
require 'simp/cli/config/item/use_fips'

require_relative 'spec_helper'

describe Simp::Cli::Config::Item::PuppetConf do
  before :context do
    @ci = Simp::Cli::Config::Item::PuppetConf.new
    @puppet_server  = 'puppet.nerd'
    @puppet_ca      = 'puppetca.nerd'
    @puppet_ca_port = '9999'
    @use_fips       = true

    previous_items = {}
    s = Simp::Cli::Config::Item::PuppetServer.new
    s.value = @puppet_server
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::PuppetCA.new
    s.value = @puppet_ca
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::PuppetCAPort.new
    s.value = @puppet_ca_port
    previous_items[ s.key ] = s
    s = Simp::Cli::Config::Item::UseFips.new
    s.value = @use_fips
    previous_items[ s.key ] = s

    @ci.config_items = previous_items
  end

  before :each do
    allow(@ci).to receive(:`)
  end

  describe "#apply" do
    before :context do
      @files_dir   = File.expand_path( 'files', File.dirname( __FILE__ ) )
      @tmp_dir     = File.expand_path( 'tmp', File.dirname( __FILE__ ) )
      @tmp_file    = File.join( @tmp_dir, 'test__puppet.conf' )
      @puppet_conf = File.join( @files_dir,'puppet.conf')
      FileUtils.mkdir_p @tmp_dir
    end

    context "when @skip_apply == true" do
      before :context do
        FileUtils.copy_file @puppet_conf, @tmp_file
        @ci.file       = @tmp_file
        @ci.skip_apply = true
        @ci.silent     = true
      end

      it "does not alter puppet.conf" do
        @ci.apply
        expect( IO.read(@tmp_file) ).to eq IO.read(@puppet_conf)
      end

      after :context do
        FileUtils.rm @tmp_file
      end
    end

    context "edits the puppet.conf file" do
      before :context do
        FileUtils.copy_file @puppet_conf, @tmp_file
        @ci.file       = @tmp_file
        @ci.skip_apply = false
        @ci.silent     = true
        @ci.apply
        @lines = File.readlines( @tmp_file ).join( "\n" )
      end

      it "configures server" do
        expect(@ci).to receive(:`).with("puppet config set server #{@puppet_server}").once
        @ci.apply
      end

      it "configures ca_server" do
        expect(@ci).to receive(:`).with("puppet config set ca_server #{@puppet_ca}").once
        @ci.apply
      end

      it "configures ca_port" do
        expect(@ci).to receive(:`).with("puppet config set ca_port #{@puppet_ca_port}").once
        @ci.apply
      end

      it "configures stringify_facts" do
        expect(@ci).to receive(:`).with("puppet config set stringify_facts false").once
        @ci.apply
      end

      it "configures digest_algorithm" do
        expect(@ci).to receive(:`).with("puppet config set digest_algorithm sha256").once
        @ci.apply
      end

      it "configures trusted_node_data" do
        expect(@ci).to receive(:`).with("puppet config set trusted_node_data true").once
        @ci.apply
      end

      it "configures keylength" do
        expect(@ci).to receive(:`).with("puppet config set keylength 2048").once
        @ci.apply
      end

      after :context do
        FileUtils.rm @tmp_file
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      ci = Simp::Cli::Config::Item::PuppetConf.new
      ci.file = 'puppet.conf'
      expect(ci.apply_summary).to eq 'Update to Puppet settings in puppet.conf unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
