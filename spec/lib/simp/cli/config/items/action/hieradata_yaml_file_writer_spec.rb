require 'simp/cli/config/items/action/hieradata_yaml_file_writer'
require 'simp/cli/config/items'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::HieradataYAMLFileWriter do
  before :all do
    @ci            = Simp::Cli::Config::Item::HieradataYAMLFileWriter.new
    @ci.silent     = true  # comment out this line to see log output
    @ci.group      = `groups`.split[0]
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)
    @files_dir       = File.expand_path( 'files', File.dirname( __FILE__ ) )
  end

  describe '#print_hieradata_yaml' do
    before :each do
      ci                = Simp::Cli::Config::Item.new
      ci.key            = 'item'
      ci.value          = 'foo'
      ci.description    = 'A simple item'
      list              = { 'foo' => ci }

      ci                = Simp::Cli::Config::ListItem.new
      ci.key            = 'list'
      ci.value          = ['one','two','three']
      ci.description    = 'A simple list'
      list[ci.key]      = ci

      ci                = Simp::Cli::Config::YesNoItem.new
      ci.key            = 'yesno'
      ci.value          = true
      ci.data_type      = :internal
      ci.description    = 'A simple yes/no item'
      list[ci.key]      = ci

      ci                = Simp::Cli::Config::ActionItem.new
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
      @ci.print_hieradata_yaml( io, @simple_item_list )
      y = YAML.load( io.string )

      expect( y ).to be_kind_of Hash
      expect( y ).not_to be_empty
      expect( y['item'] ).to  eq('foo')
      expect( y['list'] ).to  eq(['one','two','three'])
      expect( y['yesno'] ).to be_nil
    end
  end


  context 'when writing a yaml file' do
    before :each do
      # pre-populate answers list with 3 hieradata items and two non-hieradata items
      item       = Simp::Cli::Config::Item::CliSimpScenario.new
      item.value = 'simp_lite'
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpOptionsPuppetServer.new
      item.value = 'puppet.domain.tld'
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpOptionsFips.new
      item.value = false
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpRunLevel.new
      item.value = 2
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::CliNetworkHostname.new
      item.value = 'myhost.test.local'
      @ci.config_items[item.key] = item

      @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )
      @tmp_file = File.expand_path( 'hieradata_yaml_file_writer.yaml', @tmp_dir )
      @ci.file = @tmp_file
    end

    it 'writes a file' do
      @ci.apply
      expect( File.exists?( @tmp_file ) ).to be true
      expect( @ci.applied_status ).to eq :succeeded
    end

    it 'writes the correct values in sorted order' do
      @ci.apply
      actual_content = IO.read( @tmp_file )
      expected_content = IO.read(File.join(@files_dir, 'hieradata_yaml_file_writer.yaml'))
      # fix version
      expected_content.gsub!(/using simp-cli version ([0-9.])+/,
        "using simp-cli version #{Simp::Cli::VERSION}")

      expect( actual_content).to eq expected_content
    end

    it 'backs up an existing file before writing' do
      old_content = "---\nkey1:value\n"
      File.open(@tmp_file, 'w') { |file| file.write(old_content) }
      
      @ci.apply
      backup_file = "#{@tmp_file}.20170113T114203"
      expect( File.exists?( backup_file ) ).to be true
      actual_backup_content = IO.read( backup_file)
      expect( actual_backup_content).to eq old_content

      expect( File.exists?( @tmp_file ) ).to be true
      actual_content = IO.read( @tmp_file )
      expected_content = IO.read(File.join(@files_dir, 'hieradata_yaml_file_writer.yaml'))
      # fix version
      expected_content.gsub!(/using simp-cli version ([0-9.])+/,
        "using simp-cli version #{Simp::Cli::VERSION}")

      expect( actual_content).to eq expected_content
      expect( @ci.applied_status ).to eq :succeeded
    end

    it "fails when it can't set group ownership" do
      @ci.group = 'root'
      @ci.silent = false
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      ci        = Simp::Cli::Config::Item::HieradataYAMLFileWriter.new
      ci.file = '/some/path/environments/simp/simp_config_overrides.yaml'
      expect(ci.apply_summary).to eq(
        'Creation of .../environments/simp/simp_config_overrides.yaml unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like "a child of Simp::Cli::Config::Item"
end

