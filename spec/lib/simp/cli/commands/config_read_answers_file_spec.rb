require 'spec_helper'
require 'simp/cli/commands/config'
require 'fileutils'
require 'set'
require 'yaml'

describe 'Simp::Cli::Commands::Config#read_answers_file' do
  let(:files_dir) { File.join(__dir__, 'files') }

  before(:each) do
    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )
    test_env_dir = File.join(@tmp_dir, 'environments')
    simp_env_dir = File.join(test_env_dir, 'simp')
    FileUtils.mkdir(test_env_dir)
    FileUtils.cp_r(File.join(files_dir, 'environments', 'simp'), test_env_dir)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return( {
      :config => {
        'codedir' => @tmp_dir,
        'confdir' => @tmp_dir
      },
      :environment_path => test_env_dir,
      :simp_environment_path => simp_env_dir,
      :fake_ca_path => File.join(test_env_dir, 'simp', 'FakeCA')
    } )

    allow(Simp::Cli::Utils).to receive(:simp_env_datadir).and_return( File.join(simp_env_dir, 'data') )

    @yaml_file = File.join(@tmp_dir, 'answers.yaml')

    @config = Simp::Cli::Commands::Config.new
  end

  after :each do
    FileUtils.chmod 0777, @yaml_file if File.exists?(@yaml_file)
    FileUtils.remove_entry_secure @tmp_dir
  end

  it 'raises exception when file to parse cannot be accessed' do
    expect { @config.read_answers_file('oops.yaml') }.to raise_error(
      Simp::Cli::ProcessingError, "ERROR: Could not access the file 'oops.yaml'!")
  end

  it 'returns hash when file contains valid yaml' do
    File.open(@yaml_file, 'w') do |file|
      file.puts('network::dhcp: static')
      file.puts('network::hostname: puppet.test.local')
      file.puts('network::ipaddress: "1.2.3.4"')
      file.puts('network::netmask: "255.255.255.0"')
      file.puts('network::gateway: "1.2.3.1"')
      file.puts('"simp_options::dns::servers":')
      file.puts('  - "1.2.3.10"')

    end
    expected = {
      'network::dhcp' => 'static',
      'network::hostname' => 'puppet.test.local',
      'network::ipaddress' => '1.2.3.4',
      'network::netmask' => '255.255.255.0',
      'network::gateway' => '1.2.3.1',
      'simp_options::dns::servers' => ['1.2.3.10']
    }
    expect( @config.read_answers_file(@yaml_file) ).to eq expected
  end

  it 'returns empty hash when file is empty' do
    FileUtils.touch(@yaml_file)
    expected = {}
    expect( @config.read_answers_file(@yaml_file) ).to eq expected
  end

  it 'returns empty hash when file is only comments' do
    File.open(@yaml_file, 'w') do |file|
      file.puts('#')
      file.puts('# This file contains only yaml comments')
      file.puts('#')
    end
    expected = {}
    FileUtils.touch(@yaml_file)
    expected = {}
    expect( @config.read_answers_file(@yaml_file) ).to eq expected
  end

  it 'raises exception when file contains malformed yaml' do
    File.open(@yaml_file, 'w') do |file|
      file.puts('====')
      file.puts('simp_options::fips:')
    end
    expect { @config.read_answers_file(@yaml_file) }.to raise_error(
      Simp::Cli::ProcessingError, /ERROR: System configuration file '#{@yaml_file}' is corrupted/)
  end
end
