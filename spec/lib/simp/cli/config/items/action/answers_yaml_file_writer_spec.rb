require 'simp/cli/config/items/action/answers_yaml_file_writer'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::AnswersYAMLFileWriter do
  before :all do
    @ci            = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new
    @ci.silent     = true   # turn off command line summary on stdout
    @tmp_dir       = Dir.mktmpdir( File.basename(__FILE__) )
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)
  end

  describe '#print_answers_yaml' do
    before :each do
      ci                = TestItem.new
      ci.key            = 'item'
      ci.value          = 'foo'
      ci.description    = 'A simple item'
      list              = { 'foo' => ci }

      ci                = TestListItem.new
      ci.key            = 'list'
      ci.value          = ['one','two','three']
      ci.description    = 'A simple list'
      list[ci.key]      = ci

      ci                = TestYesNoItem.new
      ci.key            = 'yesno'
      ci.value          = true
      ci.data_type      = :internal
      ci.description    = 'A simple yes/no item'
      list[ci.key]      = ci

      ci                = TestActionItem.new
      ci.key            = 'action'
      ci.value          = 'unused'
      ci.description    = 'A simple action item which should not have yaml output'
      list[ci.key]      = ci

      @simple_item_list = list
    end

    it 'prints parseable yaml' do
      item = Simp::Cli::Config::Item::CliSimpScenario.new
      item.value = 'simp_lite'
      @ci.config_items[item.key] = item

      io = StringIO.new
      @ci.print_answers_yaml( io, @simple_item_list )
      y = YAML.load( io.string )

      expect( y ).to be_kind_of Hash
      expect( y ).not_to be_empty
      expect( y['item'] ).to  eq('foo')
      expect( y['list'] ).to  eq(['one','two','three'])
      expect( y['yesno'] ).to be_nil
    end
  end


  context 'when writing a yaml file' do
    before :context do
      @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )

      # pre-populate answers list with 3 hieradata items and two non-hieradata items
      item             = Simp::Cli::Config::Item::CliSimpScenario.new
      item.value       = 'simp_lite'
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::SimpOptionsPuppetServer.new
      item.value       = 'puppet.domain.tld'
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::SimpOptionsFips.new
      item.value       = false
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::SimpRunLevel.new
      item.value       = 2
      @ci.config_items[item.key] = item

      item             = Simp::Cli::Config::Item::CliNetworkHostname.new
      item.value       = 'myhost.test.local'
      @ci.config_items[item.key] = item

      @tmp_file = File.expand_path( 'answers_yaml_file_writer.yaml', @tmp_dir )
      FileUtils.mkdir_p   @tmp_dir
      @ci.file = @tmp_file
    end

    it 'writes a file' do
      @ci.apply
      expect( File.exists?( @tmp_file ) ).to be true
      expect( @ci.applied_status ).to eq :succeeded
    end

    it 'writes the correct values in sorted order' do
      @ci.apply
      actual_content = File.read( @tmp_file )
      expected_content = IO.read(File.join(@files_dir, 'answers_yaml_file_writer.yaml'))
      # fix version
      expected_content.gsub!(/cli::version: "([0-9.])+"/,
        "cli::version: \"#{Simp::Cli::VERSION}\"")

      expect( actual_content).to eq expected_content
    end

    after :context do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      ci        = Simp::Cli::Config::Item::AnswersYAMLFileWriter.new
      ci.file = 'simp_def.yaml'
      expect(ci.apply_summary).to eq('Creation of simp_def.yaml unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

