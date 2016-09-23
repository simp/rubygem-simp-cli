require 'simp/cli/config/item/puppet_fileserver'

require 'simp/cli/config/item/hostname'

require_relative 'spec_helper'

describe Simp::Cli::Config::Item::PuppetFileServer do
  before :all do
    @ci = Simp::Cli::Config::Item::PuppetFileServer.new
    @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
    @tmp_dir         = File.expand_path( 'tmp', File.dirname( __FILE__ ) )
    @tmp_file        = File.join( @tmp_dir, 'test__fileserver.conf' )
    @fileserver_conf = File.join( @files_dir,'fileserver.conf')
    @ci.silent       = true
  end

  describe "#apply" do
    context "edits the fileserver.conf file" do
      before :context do
        @ci.file         = @tmp_file
      end

      context "with a valid hostname (fqdn)" do
        before :context do
          FileUtils.mkdir_p   @tmp_dir
          FileUtils.copy_file @fileserver_conf, @tmp_file

          item             = Simp::Cli::Config::Item::Hostname.new
          item.value       = "scli.tasty.bacon"
          @ci.config_items = { 'hostname' => item }

          @ci.apply
        end

        it "configures server with correct domain" do
          lines = File.readlines( @tmp_file ).join( "\n" )
          expect( lines ).to match(%r{^\s*allow\s+\*.tasty.bacon} )
        end

        it "reports success" do
          expect( @ci.applied_status ).to eq :succeeded
        end

        after :context do
          FileUtils.rm @tmp_file
        end
      end
    end
  end

  describe "#apply_summary" do
    it 'reports unattempted status when #apply not called' do
      ci = Simp::Cli::Config::Item::PuppetFileServer.new
      ci.file = 'puppet.conf'
      expect(ci.apply_summary).to eq 'Update to Puppet fileserver settings in puppet.conf unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end
