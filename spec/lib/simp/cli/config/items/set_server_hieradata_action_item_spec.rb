require 'simp/cli/config/items/set_server_hieradata_action_item'
require_relative 'spec_helper'

class MyTestSetServerHieradataAction< Simp::Cli::Config::SetServerHieradataActionItem
  attr_accessor :hiera_to_add
  attr_accessor :merge_value

  def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
    super(puppet_env_info)
    @key          = 'puppet::set_test_server_hiera'
  end
end

describe Simp::Cli::Config::SetServerHieradataActionItem do
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

    @ci        = MyTestSetServerHieradataAction.new(@puppet_env_info)
    @ci.silent = true

    @hostname_item       = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
    @hostname_item.value = @fqdn
    @ci.config_items[@hostname_item.key] = @hostname_item

    @simple_item = TestItem.new
    @simple_item.key = 'test::simple'
    @simple_item.description = 'A test item with a simple value'
    @simple_item.value = 'new simple value'
    @ci.config_items[@simple_item.key] = @simple_item

    @mergeable_item = TestListItem.new
    @mergeable_item.key = 'test::mergeable'
    @mergeable_item.description = 'A test item with a mergeable value'
    @mergeable_item.value = ['new mergeable value 1', 'new mergeable value 2' ]
    @ci.config_items[@mergeable_item.key] = @mergeable_item

    @ci.hiera_to_add = [ @simple_item.key, @mergeable_item.key ]
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir
  end

  describe '#apply' do

    context 'with a valid dependent Items' do
      before :each do
      end

      it 'merges mergeable values & replaces the rest when merge_value = true' do
        @ci.merge_value = true

        file = File.join(@files_dir, 'host_template_with_existing_keys.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_merge_and_replace.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it 'replaces all values when merge_value = false' do
        @ci.merge_value = false

        file = File.join(@files_dir, 'host_template_with_existing_keys.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_replace_only.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it 'inserts new tag directive before classes array when key does not exist' do
        file = File.join(@files_dir, 'host_template_with_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_insert_before_classes.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it 'inserts new tag directive before first *classes array when key does not exist' do
        file = File.join(@files_dir, 'host_template_with_multiple_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_insert_before_multiple_classes.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it 'adds new tag directive to the end when key does not exist and no classes array' do
        file = File.join(@files_dir, 'host_template_without_any_classes.yaml')
        FileUtils.copy_file file, @host_file

        @ci.apply

        expect( @ci.applied_status ).to eq :succeeded
        expected = File.join(@files_dir, 'host_with_append.yaml')
        expect( IO.read(@host_file) ).to eq IO.read(expected)
      end

      it 'fails when <host>.yaml does not exist' do
        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end

      it 'fails when YAML processing fails' do
        file = File.join(@files_dir, 'host_template_with_existing_keys.yaml')
        FileUtils.copy_file file, @host_file
        expect(@ci).to receive(:load_yaml_with_comment_blocks).with(@host_file)
          .and_raise(YAML::SyntaxError, 'Malformed YAML')

        @ci.apply
        expect( @ci.applied_status ).to eq :failed
      end
    end

    context 'miscellaneous errors' do
      it 'fails with an exception when derived class does not set @hiera_to_add' do
        @ci.hiera_to_add = nil

        expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /@hiera_to_add not set for MyTestSetServerHieradataAction/)
      end

      it 'fails with an exception when cli::network::hostname Item is missing' do
        @ci.config_items.delete(@hostname_item.key)

        expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /MyTestSetServerHieradataAction could not find cli::network::hostname/)
      end

      it 'fails with an Item for a key in @hiera_to_add is missing' do
        @ci.config_items.delete(@simple_item.key)
        file = File.join(@files_dir, 'host_template_with_multiple_classes.yaml')
        FileUtils.copy_file file, @host_file

        expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /MyTestSetServerHieradataAction could not find test::simple/)
      end

      it 'fails with an Item for a key in @hiera_to_add suppresses YAML output' do
        bad_item = TestItem.new
        bad_item.key = 'test::bad'
        bad_item.value = 'value not allowed to be output in YAML'
        bad_item.skip_yaml = true
        @ci.config_items[bad_item.key] = bad_item
        @ci.hiera_to_add = [ @simple_item.key, @mergeable_item.key, bad_item.key ]
        file = File.join(@files_dir, 'host_template_with_multiple_classes.yaml')
        FileUtils.copy_file file, @host_file

        expect { @ci.apply }.to raise_error(Simp::Cli::Config::InternalError,
          /MyTestSetServerHieradataAction unable to generate YAML for test::bad/)
      end

    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      @ci.config_items[@simple_item.key] = @simple_item
      @ci.config_items[@mergeable_item.key] = @mergeable_item
      @ci.hiera_to_add = [ @simple_item.key, @mergeable_item.key ]
      expect( @ci.apply_summary ).to eq 'Setting of test::simple, test::mergeable in SIMP server <host>.yaml unattempted'
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end
