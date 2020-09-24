require 'simp/cli/command_console_logger'
require 'spec_helper'

class MyCommandConsoleLoggerTester

  include Simp::Cli::CommandConsoleLogger

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

  def set_up_and_use_logger(verbose = nil)
    if verbose
      set_up_global_logger(verbose)
    else
      set_up_global_logger
    end

    logger.trace('a trace message')
    logger.debug('a debug message')
    logger.info('an info message')
    logger.notice('a notice message')
    logger.warn('a warn message')
    logger.error('an error message')
    logger.fatal('a fatal message')
  end
end

describe Simp::Cli::CommandConsoleLogger do
  before :each do
    @command = MyCommandConsoleLoggerTester.new
  end

  describe '.add_logging_command_options' do
    it 'adds common logging options inside OptionsParser block at location specified' do
      options = { :verbose => 1 }
      expected = <<~EOM
        === My Tester Inline ===
            -i, --input FILE                 Input file
            -v, --verbose                    Verbose console output (stacks).
            -q, --quiet                      Quiet console output.  Only errors are
                                             reported to the console.
            -o, --output FILE                Output file
            -h, --help                       Print this message
      EOM
      expect { @command.parse_command_line_add_inline([ '-h' ], options) }.to output(expected).to_stdout
    end

    it 'adds common logging options to existing OptionsParser prior to tail_on' do
      options = { :verbose => 1 }
      expected = <<~EOM
        === My Tester Append ===
            -i, --input FILE                 Input file
            -o, --output FILE                Output file
            -v, --verbose                    Verbose console output (stacks).
            -q, --quiet                      Quiet console output.  Only errors are
                                             reported to the console.
            -h, --help                       Print this message
      EOM
      expect { @command.parse_command_line_append([ '-h' ], options) }.to output(expected).to_stdout
    end

    it 'increments verbosity when --verbose option specified' do
      options = { :verbose => 2 }
      @command.parse_command_line_add_inline([ '-v' ], options)
      expect( options[:verbose] ).to eq 3
    end

    it 'uses base verbosity of NOTICE and above when :verbose missing from options' do
      options = {}
      @command.parse_command_line_add_inline([ '-v' ], options)
      expect( options[:verbose] ).to eq 1
    end

    it 'stacks verbosity when multiple -v options specified' do
      options = { :verbose => 0 }
      @command.parse_command_line_add_inline([ '-vvv' ], options)
      expect( options[:verbose] ).to eq 3
    end

    it 'sets verbosity to ERROR and above when --quiet option is specified' do
      options = { :verbose => 0 }
      @command.parse_command_line_add_inline([ '--quiet' ], options)
      expect( options[:verbose] ).to eq -1
    end

  end

  describe '.set_up_global_logger' do
    before :each do
      # Ideally, we would like to test with default log levels.  However,
      # because we are dealing with a singleton, when this test is run within
      # the entire test suite, ::Logger may have already had its log levels
      # adjusted.  So, here, set the log levels to match the default levels.
      Simp::Cli::Logging.logger.levels(:error, :error)

      # required to capture console output manage by Highline global
      @input = StringIO.new("\n")
      @output = StringIO.new
      HighLine.default_instance = HighLine.new(@input, @output)
    end

    after :each do
      @input.close
      @output.close
      HighLine.default_instance = HighLine.new
    end


    context 'console verbosity' do
      it 'sets default console verbosity to NOTICE' do
        @command.set_up_and_use_logger

        expected_console = <<~EOM
          a notice message
          a warn message
          an error message
          a fatal message
        EOM
        expect( @output.string ).to eq expected_console
      end

      it 'sets specified console verbosity' do
        verbose = 3
        @command.set_up_and_use_logger(verbose)

        expected_console = <<~EOM
          a trace message
          a debug message
          an info message
          a notice message
          a warn message
          an error message
          a fatal message
        EOM
        expect( @output.string ).to eq expected_console
      end
    end
  end
end

