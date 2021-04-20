require 'simp/cli/config/items/action/hieradata_yaml_file_writer'
require 'simp/cli/config/items'
require_relative '../spec_helper'

describe Simp::Cli::Config::Item::HieradataYAMLFileWriter do
  before :each do
    @files_dir = File.expand_path( 'files', File.dirname( __FILE__ ) )

    @puppet_env_info = {
      :puppet_config => { 'modulepath' => '/does/not/matter' },
      :puppet_group  => `groups`.split[0]
    }

    @ci            = Simp::Cli::Config::Item::HieradataYAMLFileWriter.new(@puppet_env_info)
    @ci.silent     = true  # comment out this line to see log output
    @ci.start_time = Time.new(2017, 1, 13, 11, 42, 3)
  end

  describe '#print_hieradata_yaml' do
    before :each do
      # first 2 items will have the default data_type of :global_hiera
      ci                = TestItem.new(@puppet_env_info)
      ci.key            = 'item'
      ci.value          = 'foo'
      ci.description    = 'A simple item'
      list              = { 'foo' => ci }

      ci                = TestListItem.new(@puppet_env_info)
      ci.key            = 'list'
      ci.value          = ['one','two','three']
      ci.description    = 'A simple list'
      list[ci.key]      = ci

      ci                = TestYesNoItem.new(@puppet_env_info)
      ci.key            = 'yesno'
      ci.value          = true
      ci.data_type      = :internal
      ci.description    = 'A simple yes/no item'
      list[ci.key]      = ci

      # ActionItems have the data_type of :none
      ci                = TestActionItem.new(@puppet_env_info)
      ci.key            = 'action'
      ci.value          = 'unused'
      ci.description    = 'A simple action item which should not have yaml output'
      list[ci.key]      = ci

      # ClassItems have the data_type of :global_class
      ci                = TestClassItem.new(@puppet_env_info)
      ci.key            = 'some::class::one'
      ci.description    = 'A class item whose key should be added to simp::classes'
      list[ci.key]      = ci

      ci                = TestClassItem.new(@puppet_env_info)
      ci.key            = 'some::class::two'
      ci.description    = 'A class item whose key should be added to simp::classes'
      list[ci.key]      = ci

      @simple_item_list = list
    end

    it 'prints parseable yaml' do
      item = Simp::Cli::Config::Item::CliSimpScenario.new(@puppet_env_info)
      item.value = 'simp_lite'
      @ci.config_items[item.key] = item

      io = StringIO.new
      @ci.print_hieradata_yaml( io, @simple_item_list )
      y = YAML.load( io.string )

      expect( y ).to be_kind_of Hash
      expect( y ).not_to be_empty
      expect( y['item'] ).to  eq('foo')
      expect( y['list'] ).to  eq(['one','two','three'])
      expect( y.key?('yesno') ).to be false
      expect( y.key?('action') ).to be false
      expect( y['simp::classes'] ).to  eq(['some::class::one','some::class::two'])
    end
  end


  context 'when writing a yaml file' do
    before :each do
      # pre-populate answers list with 3 hieradata items and two non-hieradata items
      item       = Simp::Cli::Config::Item::CliSimpScenario.new(@puppet_env_info)
      item.value = 'simp_lite'
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpOptionsPuppetServer.new(@puppet_env_info)
      item.value = 'puppet.domain.tld'
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpOptionsFips.new(@puppet_env_info)
      item.value = false
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::SimpRunLevel.new(@puppet_env_info)
      item.value = 2
      @ci.config_items[item.key] = item

      item       = Simp::Cli::Config::Item::CliNetworkHostname.new(@puppet_env_info)
      item.value = 'myhost.test.local'
      @ci.config_items[item.key] = item

      @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )
      @tmp_file = File.expand_path( 'hieradata_yaml_file_writer.yaml', @tmp_dir )
      @ci.file = @tmp_file
    end

    it 'writes a file' do
      @ci.apply
      expect( File.exist?( @tmp_file ) ).to be true
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
      expect( File.exist?( backup_file ) ).to be true
      actual_backup_content = IO.read( backup_file)
      expect( actual_backup_content).to eq old_content

      expect( File.exist?( @tmp_file ) ).to be true
      actual_content = IO.read( @tmp_file )
      expected_content = IO.read(File.join(@files_dir, 'hieradata_yaml_file_writer.yaml'))
      # fix version
      expected_content.gsub!(/using simp-cli version ([0-9.])+/,
        "using simp-cli version #{Simp::Cli::VERSION}")

      expect( actual_content).to eq expected_content
      expect( @ci.applied_status ).to eq :succeeded
    end

    it 'writes out a simp::classes array when :global_class Items exist' do
      item = Simp::Cli::Config::Item::SimpYumRepoInternetSimpClass.new(@puppet_env_info)
      @ci.config_items[item.key] = item

      item = Simp::Cli::Config::Item::SimpYumRepoLocalOsUpdatesClass.new(@puppet_env_info)
      @ci.config_items[item.key] = item

      item = Simp::Cli::Config::Item::SimpYumRepoLocalSimpClass.new(@puppet_env_info)
      @ci.config_items[item.key] = item

      @ci.apply

      actual_content = IO.read( @tmp_file )
      expected_content = IO.read(File.join(@files_dir, 'hieradata_yaml_file_writer_with_classes.yaml'))
      # fix version
      expected_content.gsub!(/using simp-cli version ([0-9.])+/,
        "using simp-cli version #{Simp::Cli::VERSION}")

      expect( actual_content).to eq expected_content
    end

    it "fails when it can't set group ownership" do
      allow(FileUtils).to receive(:chown).with(nil, `groups`.split[0], @ci.file).and_raise( ArgumentError )
      @ci.apply
      expect( @ci.applied_status ).to eq :failed
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
    end
  end

  describe '#apply_summary' do
    it 'reports unattempted status when #apply not called' do
      ci        = Simp::Cli::Config::Item::HieradataYAMLFileWriter.new(@puppet_env_info)
      ci.file = '/some/path/environments/simp/simp_config_overrides.yaml'
      expect(ci.apply_summary).to eq(
        'Creation of /etc/.../environments/simp/simp_config_overrides.yaml unattempted')
    end
  end

  it_behaves_like "an Item that doesn't output YAML"
  it_behaves_like 'a child of Simp::Cli::Config::Item'
end

