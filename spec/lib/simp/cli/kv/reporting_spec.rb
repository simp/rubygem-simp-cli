require 'simp/cli/kv/reporting'
require 'spec_helper'
require 'tmpdir'

class MyKvReportingTester

  include Simp::Cli::Kv::Reporting

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

describe Simp::Cli::Kv::Reporting do
  before :each do
    @command = MyKvReportingTester.new
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
      expect( options[:verbose] ).to eq(3)
    end

    it 'uses base verbosity of NOTICE and above when :verbose missing from options' do
      options = {}
      @command.parse_command_line_add_inline([ '-v' ], options)
      expect( options[:verbose] ).to eq(1)
    end

    it 'stacks verbosity when multiple -v options specified' do
      options = { :verbose => 0 }
      @command.parse_command_line_add_inline([ '-vvv' ], options)
      expect( options[:verbose] ).to eq(3)
    end

    it 'sets verbosity to ERROR and above when --quiet option is specified' do
      options = { :verbose => 0 }
      @command.parse_command_line_add_inline([ '--quiet' ], options)
      expect( options[:verbose] ).to eq(-1)
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
        expect( @output.string ).to eq(expected_console)
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
        expect( @output.string ).to eq(expected_console)
      end
    end
  end

  describe '.entity_description' do
    let(:entity) { 'keyX' }

    it 'should return global string when :global is true' do
      opts = { :global => true, :env => 'production' }
      expected = "global '#{entity}'"
      expect( @command.entity_description(entity, opts) ).to eq(expected)
    end

    it 'should return environment string when :global is false' do
      opts = { :global => false, :env => 'production' }
      expected = "'#{entity}' in '#{opts[:env]}' environment"
      expect( @command.entity_description(entity, opts) ).to eq(expected)
    end
  end

  describe '.report_results' do
    before :each do
      @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
      @outfile = File.join(@tmp_dir, 'result.json')

      # required to capture console output manage by Highline global
      @input = StringIO.new("\n")
      @output = StringIO.new
      HighLine.default_instance = HighLine.new(@input, @output)
    end

    after :each do
      FileUtils.remove_entry_secure @tmp_dir
      @input.close
      @output.close
      HighLine.default_instance = HighLine.new
    end

    let(:id) { 'my_id' }
    let(:results) { { 'value' => 1, 'metadata' => { 'foo' => 'bar' } } }
    let(:results_json_string) {
      <<~EOM
        {
          "value": 1,
          "metadata": {
            "foo": "bar"
          }
        }
      EOM
    }

    it 'should log to console when outfile=nil' do
      @command.report_results(id, results, nil)
      expect( @output.string ).to eq(results_json_string)
    end

    it 'should write result to file and log write to console when outfile specified' do
      @command.report_results(id, results, @outfile)
      expect( File.read(@outfile) ).to eq(results_json_string)
      expect( @output.string ).to eq("Output for #{id} written to #{@outfile}\n")
    end

    it 'should fail if JSON cannot be generated from result' do
      # JSON.pretty_generate is extremely robust. Couldn't create input
      # that causes the failure, so will mock the failure instead.
      allow(JSON).to receive(:pretty_generate).and_raise(
        JSON::JSONError, 'generate error')
      expect{ @command.report_results(id, results, nil) }.to raise_error(
        Simp::Cli::ProcessingError,
        /Results could not be converted to JSON: generate error/)
    end

    it 'should fail if file cannot be written' do
      allow(File).to receive(:open).with(any_args).and_call_original
      allow(File).to receive(:open).with(@outfile, 'w').and_raise(
        Errno::EACCES, 'failed file write')

      expect { @command.report_results(id, results, @outfile) }
        .to raise_error( Simp::Cli::ProcessingError,
        "Failed to write #{id} output to #{@outfile}: "\
        "Permission denied - failed file write")
    end
  end
end

