require 'simp/cli/commands/bootstrap'

describe 'Simp::Cli::Command::Bootstrap#run' do
  let(:files_dir) { File.join(File.dirname(__FILE__), 'files') }

  before(:each) do
    @tmp_dir  = Dir.mktmpdir( File.basename(__FILE__) )
    test_env_dir = File.join(@tmp_dir, 'environments')
    simp_env_dir = File.join(test_env_dir, 'simp')
    FileUtils.mkdir(test_env_dir)
    FileUtils.cp_r(File.join(files_dir, 'environments', 'simp'), test_env_dir)

    allow(Simp::Cli::Utils).to receive(:puppet_info).and_return( {
      :config => {
        'agent_disabled_lockfile' => File.join(@tmp_dir, 'agent_disable_lockfile'),
        'codedir'                 => @tmp_dir,
        'confdir'                 => @tmp_dir,
        'hostcert'                => File.join(@tmp_dir, 'test_host.pem'),
        'hostprivkey'             => File.join(@tmp_dir, 'test_host.key'),
        'rundir'                  => File.join(@tmp_dir, 'rundir'),
        'ssldir'                  => File.join(@tmp_dir, 'ssldir'),
        'vardir'                  => File.join(@tmp_dir, 'vardir')
      },
      :environment_path      => test_env_dir,
      :simp_environment_path => simp_env_dir,
      :fake_ca_path          => File.join(test_env_dir, 'simp', 'FakeCA'),
      :is_pe                 => false
    } )

    @bootstrap = Simp::Cli::Commands::Bootstrap.new
  end

  after :each do
    FileUtils.remove_entry_secure @tmp_dir, true
    Facter.reset  # make sure this test's facts don't affect other tests
  end

  context 'help' do
    it 'prints help message' do
      options_help = <<-EOM
OPTIONS:
    -k, --kill_agent                 Ignore agent_catalog_run_lockfile
                                     status and force kill active puppet
                                     agents at the beginning of bootstrap.
    -r, --[no-]remove_ssldir         Remove the existing puppet ssldir.
                                     If unspecified, user will be prompted
                                     for action to take.
    -t, --[no-]track                 Enables/disables the tracker.
                                     Default is enabled.
    -u, --unsafe                     Run bootstrap in 'unsafe' mode.
                                     Interrupts are NOT captured and ignored,
                                     which may result in a corrupt system.
                                     Useful for debugging.
                                     Default is SAFE.
    -w MIN,                          Number of minutes to wait for the
        --puppetserver-wait-minutes  puppetserver to start.
                                     Default is 5 minutes.
    -v, --[no-]verbose               Enables/disables verbose mode. Prints out
                                     verbose information.
    -h, --help                       Print out this message.
      EOM
      expected_regex = Regexp.new(Regexp.escape(options_help.strip))
      expect{ @bootstrap.run(['-h']) }.to output(expected_regex).to_stdout
    end
  end

  context 'invalid options' do
    it 'fails unless --puppetserver-wait-minutes argument is > 0' do
      expect{ @bootstrap.run(['--puppetserver-wait-minutes', '0']) }.to raise_error(/Invalid puppetserver wait minutes/)
      expect{ @bootstrap.run(['-w', '-1']) }.to raise_error(/Invalid puppetserver wait minutes/)
    end

    it 'fails unless --puppetserver-wait-minutes argument parses to a number' do
      expect{ @bootstrap.run(['--puppetserver-wait-minutes', 'oops']) }.to raise_error(OptionParser::InvalidArgument)
    end
  end
end
