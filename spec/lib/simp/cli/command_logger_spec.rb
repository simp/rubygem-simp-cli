require 'simp/cli/command_logger'
require 'spec_helper'
require 'tmpdir'

class MyCommandLoggerTester

  include Simp::Cli::CommandLogger

  def parse_command_line_add_inline(args, options)
    opt_parser      = OptionParser.new do |opts|
      opts.banner    = "=== My Tester Inline ==="
      opts.on('-i', '--input FILE', 'Input file') do |file|
        options[:input] = file
      end

      add_logging_command_options(opts, options)

      opts.on('-o', '--output FILE', 'Output file') do |file|
        options[:output] = file
      end

      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
      end
    end

    opt_parser.parse!(args)
  end

  def parse_command_line_append(args, options)
    opt_parser      = OptionParser.new do |opts|
      opts.banner    = "=== My Tester Append ==="
      opts.on('-i', '--input FILE', 'Input file') do |file|
        options[:input] = file
      end

      opts.on('-o', '--output FILE', 'Output file') do |file|
        options[:output] = file
      end
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
      end
    end

    add_logging_command_options(opt_parser, options)

    opt_parser.parse!(args)
  end

  def set_up_and_use_logger(options, log_messages = true)
    set_up_global_logger(options)

    if log_messages
      logger.trace('a trace message')
      logger.debug('a debug message')
      logger.info('an info message')
      logger.notice('a notice message')
      logger.warn('a warn message')
      logger.error('an error message')
      logger.fatal('a fatal message')
    end
  end
end

def normalize_logfile(content)
  # lazy way to normalize out timestamp at beginning
  content.gsub(/[0-9]{4}-[0-9]{2}-[0-9]{2} ([0-9]{2}:){3} /,'')
end

describe Simp::Cli::CommandLogger do
  before :each do
    @command = MyCommandLoggerTester.new
  end

  describe '.add_logging_command_options' do
    it 'adds common logging options inside OptionsParser block at location specified' do
      options = { :log_basename => 'test.log', :verbose => 1 }
      expected = <<-EOM
=== My Tester Inline ===
    -i, --input FILE                 Input file
    -l, --log-file FILE              Log file. Defaults to
                                     #{Simp::Cli::SIMP_CLI_HOME}/test.log.<timestamp>
    -v, --verbose                    Verbose console output (stacks). All details
                                     are recorded in the log file regardless.
    -q, --quiet                      Quiet console output.  Only errors are
                                     reported to the console. All details are
                                     recorded in the log file regardless.
        --console-only               Suppress logging to file.
    -o, --output FILE                Output file
    -h, --help                       Print this message
      EOM
      expect { @command.parse_command_line_add_inline([ '-h' ], options) }.to output(expected).to_stdout
    end

    it 'adds common logging options to existing OptionsParser prior to tail_on' do
      options = { :log_basename => 'test.log', :verbose => 1 }
      expected = <<-EOM
=== My Tester Append ===
    -i, --input FILE                 Input file
    -o, --output FILE                Output file
    -l, --log-file FILE              Log file. Defaults to
                                     #{Simp::Cli::SIMP_CLI_HOME}/test.log.<timestamp>
    -v, --verbose                    Verbose console output (stacks). All details
                                     are recorded in the log file regardless.
    -q, --quiet                      Quiet console output.  Only errors are
                                     reported to the console. All details are
                                     recorded in the log file regardless.
        --console-only               Suppress logging to file.
    -h, --help                       Print this message
      EOM
      expect { @command.parse_command_line_append([ '-h' ], options) }.to output(expected).to_stdout
    end

    it 'fails if :log_basename does not exist in options' do
      expect { @command.parse_command_line_append([ '-h' ], {}) }.to raise_error(
        RuntimeError,
        'add_logging_command_options: options Hash must contain :log_basename key'
      )
    end

    it 'sets :log_file from -l option' do
      options = { :log_basename => 'test.log', :verbose => 1 }
      @command.parse_command_line_add_inline([ '-l', 'mytest.log' ], options)
      expect( options[:log_file] ).to eq File.expand_path('mytest.log')
    end

    it 'increments verbosity when --verbose option specified' do
      options = { :log_basename => 'test.log', :verbose => 2 }
      @command.parse_command_line_add_inline([ '-v' ], options)
      expect( options[:verbose] ).to eq 3
    end

    it 'uses base verbosity of NOTICE and above when :verbose missing from options' do
      options = { :log_basename => 'test.log' }
      @command.parse_command_line_add_inline([ '-v' ], options)
      expect( options[:verbose] ).to eq 1
    end

    it 'stacks verbosity when multiple -v options specified' do
      options = { :log_basename => 'test.log', :verbose => 0 }
      @command.parse_command_line_add_inline([ '-vvv' ], options)
      expect( options[:verbose] ).to eq 3
    end

    it 'sets verbosity to ERROR and above when --quiet option is specified' do
      options = { :log_basename => 'test.log', :verbose => 0 }
      @command.parse_command_line_add_inline([ '--quiet' ], options)
      expect( options[:verbose] ).to eq -1
    end

  end

  describe '.set_up_global_logger' do
    let(:time_now) { Time.new(2017, 1, 13, 11, 42, 3) }
    before :each do
      @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
      @log_file = File.join(@tmp_dir, 'log.txt')

      # Ideally, we would like to test with default log levels.  However,
      # because we are dealing with a singleton, when this test is run within
      # the entire test suite, ::Logger may have already had its log levels
      # adjusted.  So, here, set the log levels to match the default levels.
      Simp::Cli::Logging.logger.levels(:error, :error)

      allow(Time).to receive(:now).and_return(time_now)

      # required to capture console output manage by Highline global
      @input = StringIO.new("\n")
      @output = StringIO.new
      @prev_terminal = $terminal
      $terminal = HighLine.new(@input, @output)
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir

      @input.close
      @output.close
      $terminal = @prev_terminal
    end

    context 'logfile creation' do
      let(:log_basename) { 'command_logger_test.log' }
      let(:start_time)   { Time.new(2019, 1, 2, 3, 4, 5) }

      after :each do
        FileUtils.rm_f(File.join(Simp::Cli::SIMP_CLI_HOME, 'command_logger_test.log.20170113T114203'))
        FileUtils.rm_f(File.join(Simp::Cli::SIMP_CLI_HOME, 'command_logger_test.log.20190102T030405'))
      end

      it 'opens default logfile named with start time when logfile is unspecified' do
        options = { :log_basename => 'command_logger_test.log', :start_time => start_time }
        @command.set_up_and_use_logger(options)

        expect( options[:log_file] ).to eq File.join(Simp::Cli::SIMP_CLI_HOME, 'command_logger_test.log.20190102T030405')
        expect( File.exist?(options[:log_file]) ).to eq true
      end

      it 'opens default logfile named with Time.now when logfile & start time are unspecified' do
        options = { :log_basename => 'command_logger_test.log' }
        @command.set_up_and_use_logger(options)

        expect( options[:start_time] ).to eq time_now
        expect( options[:log_file] ).to eq File.join(Simp::Cli::SIMP_CLI_HOME, 'command_logger_test.log.20170113T114203')
        expect( File.exist?(options[:log_file]) ).to eq true
      end

      it 'opens specified logfile' do
        options = { :log_file => File.join(@tmp_dir, 'command_logger_test.log') }

        @command.set_up_and_use_logger(options)
        expect( options[:start_time] ).to eq time_now
        expect( options[:log_file] ).to eq File.join(File.join(@tmp_dir, 'command_logger_test.log'))
        expect( File.exist?(options[:log_file]) ).to eq true
      end

      it 'fails if neither :log_file nor :log_basename is specified' do
        expect { @command.set_up_and_use_logger({}) }.to raise_error(
          RuntimeError,
          'set_up_global_logger: options Hash must contain :log_basename or :log_file'
        )
      end

      it 'does not open file logging when :log_file = :none' do
        allow(FileUtils).to receive(:mkdir_p)
        mock_logger = object_double('Mock Logger', {
          :open_logfile  => nil,
          :levels        => nil
        })
        allow(@command).to receive(:logger).and_return(mock_logger)

        options = { :log_file => :none }

        @command.set_up_and_use_logger(options, false)
        expect(FileUtils).not_to have_received(:mkdir_p)
        expect(mock_logger).not_to have_received(:open_logfile)
      end
    end

    context 'console and logger verbosity' do
      let(:expected_file_output) { <<-EOM
2017-01-13 11:42:03: a debug message
2017-01-13 11:42:03: an info message
2017-01-13 11:42:03: a notice message
2017-01-13 11:42:03: a warn message
2017-01-13 11:42:03: an error message
2017-01-13 11:42:03: a fatal message
        EOM
      }

      it 'sets default console verbosity to NOTICE and file verbosity to DEBUG' do
        options = { :log_file => File.join(@tmp_dir, 'command_logger_test.log') }
        @command.set_up_and_use_logger(options)

        expected_console = <<-EOM
a notice message
a warn message
an error message
a fatal message
        EOM
        expect( @output.string ).to eq expected_console
        expect( IO.read(options[:log_file]) ).to eq expected_file_output
      end

      it 'sets specified console verbosity, but leaves file verbosity at DEBUG' do
        options = { :log_file => File.join(@tmp_dir, 'command_logger_test.log'), :verbose => 3 }
        @command.set_up_and_use_logger(options)

        expected_console = <<-EOM
a trace message
a debug message
an info message
a notice message
a warn message
an error message
a fatal message
        EOM
        expect( @output.string ).to eq expected_console
        expect( IO.read(options[:log_file]) ).to eq expected_file_output
      end

    end
  end
end

