require 'simp/cli/commands/bootstrap'

describe 'Simp::Cli::Command::Bootstrap' do
  let(:files_dir) { File.join(__dir__, 'files') }

  before(:each) do
    @bootstrap = Simp::Cli::Commands::Bootstrap.new
  end

  context '#run' do
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

  context '#validate_host_sanity' do
    it 'succeeds if the system is sane' do
      expect(@bootstrap).to receive(:get_hostname).and_return('foo.bar.baz')
      expect{@bootstrap.send(:validate_host_sanity)}.to_not raise_error
    end

    it 'fails if the system does not have a FQDN' do
      # Override the fail method so that we can snag the message that is sent
      allow(@bootstrap).to receive(:fail) do |message, options='', console_prefix=''|
        message
      end

      expect(@bootstrap).to receive(:get_hostname).and_return('foo')
      expect(@bootstrap.send(:validate_host_sanity)).to match(/fully qualified hostname/)
    end
  end
end
