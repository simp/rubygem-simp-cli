require 'simp/cli/config/items/add_server_class_action_item'
require_relative 'spec_helper'

class MyTestAddServerClassAction< Simp::Cli::Config::AddServerClassActionItem
  attr_accessor :class_to_add
  def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
    @class_to_add = 'my::test'  # pre-define, so description is set
    super(puppet_env_info)
    @key          = 'puppet::add_my_test_class_to_server'
  end
end

describe Simp::Cli::Config::AddServerClassActionItem do
  before :each do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    @tmp_dir   = Dir.mktmpdir( File.basename(__FILE__) )
    @hosts_dir = File.join(@tmp_dir, 'hosts')
    FileUtils.mkdir(@hosts_dir)

    @fqdn = 'hostname.domain.tld'
    @host_file = File.join( @hosts_dir, "#{@fqdn}.yaml" )

    @puppet_env_info = {
      :puppet_config      => { 'modulepath' => '/does/not/matter' },
      :puppet_env_datadir => @tmp_dir
    }

    @ci        = MyTestAddServerClassAction.new(@puppet_env_info)
    @ci.silent = true
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#apply' do

    context 'with a valid cli::network::hostname Item' do
      before :each do
        item       = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
        item.value = @fqdn
        @ci.config_items[item.key] = item
      end

      it "adds specified class to existing 'simp::server::classes' in <host>.yaml" do
        file = File.join(@files_dir, 'host_template_with_multiple_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_multiple_classes.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it "adds specified class to existing 'simp::classes' in <host>.yaml" do
        file = File.join(@files_dir, 'host_template_with_simp_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_simp_classes.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it "adds specified class to existing 'classes' in <host>.yaml" do
        file = File.join(@files_dir, 'host_template_with_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_classes.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it "inserts 'simp::server::classes' with specified class when no classes array exists" do
        file = File.join(@files_dir, 'host_template_without_any_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_simp_server_classes_inserted.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it "merges specified class into appropriate classes array in <host>.yaml" do
        file = File.join(@files_dir, 'host_with_multiple_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expect( IO.read(@host_file) ).to eq IO.read(file)
      end

      it 'fails when <host>.yaml does not exist' do
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end

      it 'fails when YAML processing fails' do
        file = File.join(@files_dir, 'host_template_with_multiple_classes.yaml')
        FileUtils.copy_file file, @host_file
        expect(@ci).to receive(:load_yaml_with_comment_blocks).with(@host_file)
          .and_raise(YAML::SyntaxError, 'Malformed YAML')

        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    context 'miscellaneous errors' do
      it 'fails with an exception when derived class does not set @class_to_add' do
        ci_bad = MyTestAddServerClassAction.new(@puppet_env_info)
        ci_bad.class_to_add = nil  # must be set
        ci_bad.silent  = true

        item = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
        item.value = @fqdn
        ci_bad.config_items[item.key] = item

        expect { ci_bad.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /@class_to_add empty for MyTestAddServerClassAction/)
      end

      it 'fails with an exception when cli::network::hostname Item is missing' do
        expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /MyTestAddServerClassAction could not find cli::network::hostname/)
      end
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      expect( @ci.apply_summary ).to eq 'Addition of my::test to SIMP server <host>.yaml class list unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
