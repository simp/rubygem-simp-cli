require 'simp/cli/logging'
require 'spec_helper'
require 'tmpdir'

class MyLogTesterA
  include Simp::Cli::Logging

  def self.use_logger
    logger.trace("#{self.inspect}: this is an already-formatted trace message".magenta)
    logger.debug("#{self.inspect}: this is an unformatted debug message with a {")
    logger.info("#{self.inspect}: this is a single-part, formatted info message with a }", [:BOLD, :RED])
    logger.notice("#{self.inspect}: this is an already-formatted notice message".bold.green)
    logger.warn("#{self.inspect}: this is a", nil, ' multi-part ', [:BOLD], 'formatted warn message')
    logger.error("#{self.inspect}: this is a message that does not end in a newline when sent to the console... ")
    logger.error("#{self.inspect}: continuation first line")
    logger.fatal("#{self.inspect}: this is a", [], ' message ', [:RED],
      'that does not end in a newline when sent to the console... ')
    logger.fatal("#{self.inspect}: continuation second line")
  end
end

class MyLogTesterB
  include Simp::Cli::Logging

  def use_logger
    logger.trace("#{self.class}: this is an already-formatted trace message".magenta)
    logger.debug("#{self.class}: this is an unformatted debug message with a {")
    logger.info("#{self.class}: this is a single-part, formatted info message with a }", [:BOLD, :RED])
    logger.notice("#{self.class}: this is an already-formatted notice message".bold.green)
    logger.warn("#{self.class}: this is a", nil, ' multi-part ', [:BOLD], 'formatted warn message')
    logger.error("#{self.class}: this is a message that does not end in a newline when sent to the console... ")
    logger.error("#{self.class}: continuation first line")
    logger.fatal("#{self.class}: this is a", [], ' message ', [:RED],
      'that does not end in a newline when sent to the console... ')
    logger.fatal("#{self.class}: continuation second line")
  end
end

def normalize_logfile(content)
  # lazy way to normalize out timestamp at beginning
  content.gsub(/[0-9]{4}-[0-9]{2}-[0-9]{2} ([0-9]{2}:){3} /,'')
end

describe Simp::Cli::Logging do
  before :each do
    @tmp_dir = Dir.mktmpdir( File.basename( __FILE__ ) )
    @log_file = File.join(@tmp_dir, 'log.txt')
    Simp::Cli::Logging.logger.open_logfile(@log_file)

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

  describe 'log to console and file allowing error and above log messages' do
    before :each do
      # Ideally, we would like to test with default log levels.  However,
      # because we are dealing with a singleton, when this test is run within
      # the entire test suite, ::Logger may have already had its log levels
      # adjusted.  So, here, set the log levels to match the default levels.
      Simp::Cli::Logging.logger.levels(:error, :error)
    end

    context 'when included Logging module used in a class method' do
      it 'logs formatted and unformatted error and above messages to console and log file, respectively' do
        MyLogTesterA.use_logger

        expected_formatted_output = <<EOM
MyLogTesterA: this is a message that does not end in a newline when sent to the console... MyLogTesterA: continuation first line
MyLogTesterA: this is a\e[31m message\e[0m that does not end in a newline when sent to the console... MyLogTesterA: continuation second line
EOM
        expect( @output.string ).to eq expected_formatted_output

        expected_file_output = <<EOM
MyLogTesterA: this is a message that does not end in a newline when sent to the console... 
MyLogTesterA: continuation first line
MyLogTesterA: this is a message that does not end in a newline when sent to the console... 
MyLogTesterA: continuation second line
EOM
        actual_file_output = normalize_logfile(IO.read(@log_file))
        expect( actual_file_output ).to eq expected_file_output
      end
    end

    context 'when included Logging module used in an instance method' do
      it 'logs formatted and unformatted error and above messages to console and log file, respectively' do
        MyLogTesterB.new.use_logger

        expected_formatted_output = <<EOM
MyLogTesterB: this is a message that does not end in a newline when sent to the console... MyLogTesterB: continuation first line
MyLogTesterB: this is a\e[31m message\e[0m that does not end in a newline when sent to the console... MyLogTesterB: continuation second line
EOM
        expect( @output.string ).to eq expected_formatted_output

        expected_file_output = <<EOM
MyLogTesterB: this is a message that does not end in a newline when sent to the console... 
MyLogTesterB: continuation first line
MyLogTesterB: this is a message that does not end in a newline when sent to the console... 
MyLogTesterB: continuation second line
EOM
        actual_file_output = normalize_logfile(IO.read(@log_file))
        expect( actual_file_output ).to eq expected_file_output
      end
    end
  end

  describe 'log to console and file allowing all log messages' do
    before :each do
      Simp::Cli::Logging.logger.levels(:trace, :trace)
    end

    context 'when included Logging module used in a class method' do
      it 'logs formatted and unformatted trace and above messages to console and log file, respectively' do
        MyLogTesterA.use_logger

        expected_formatted_output = <<EOM
\e[35mMyLogTesterA: this is an already-formatted trace message\e[0m
MyLogTesterA: this is an unformatted debug message with a {
\e[1m\e[31mMyLogTesterA: this is a single-part, formatted info message with a }\e[0m
\e[32m\e[1mMyLogTesterA: this is an already-formatted notice message\e[0m\e[0m
MyLogTesterA: this is a\e[1m multi-part\e[0m formatted warn message
MyLogTesterA: this is a message that does not end in a newline when sent to the console... MyLogTesterA: continuation first line
MyLogTesterA: this is a\e[31m message\e[0m that does not end in a newline when sent to the console... MyLogTesterA: continuation second line
EOM
        expect( @output.string ).to eq expected_formatted_output

        expected_file_output = <<EOM
MyLogTesterA: this is an already-formatted trace message
MyLogTesterA: this is an unformatted debug message with a {
MyLogTesterA: this is a single-part, formatted info message with a }
MyLogTesterA: this is an already-formatted notice message
MyLogTesterA: this is a multi-part formatted warn message
MyLogTesterA: this is a message that does not end in a newline when sent to the console... 
MyLogTesterA: continuation first line
MyLogTesterA: this is a message that does not end in a newline when sent to the console... 
MyLogTesterA: continuation second line
EOM
        actual_file_output = normalize_logfile(IO.read(@log_file))
        expect( actual_file_output ).to eq expected_file_output
      end
    end

    context 'when included Logging module used in an instance method' do
      it 'logs formatted and unformatted trace and above messages to console and log file, respectively' do
        MyLogTesterB.new.use_logger

        expected_formatted_output = <<EOM
\e[35mMyLogTesterB: this is an already-formatted trace message\e[0m
MyLogTesterB: this is an unformatted debug message with a {
\e[1m\e[31mMyLogTesterB: this is a single-part, formatted info message with a }\e[0m
\e[32m\e[1mMyLogTesterB: this is an already-formatted notice message\e[0m\e[0m
MyLogTesterB: this is a\e[1m multi-part\e[0m formatted warn message
MyLogTesterB: this is a message that does not end in a newline when sent to the console... MyLogTesterB: continuation first line
MyLogTesterB: this is a\e[31m message\e[0m that does not end in a newline when sent to the console... MyLogTesterB: continuation second line
EOM
        expect( @output.string ).to eq expected_formatted_output

        expected_file_output = <<EOM
MyLogTesterB: this is an already-formatted trace message
MyLogTesterB: this is an unformatted debug message with a {
MyLogTesterB: this is a single-part, formatted info message with a }
MyLogTesterB: this is an already-formatted notice message
MyLogTesterB: this is a multi-part formatted warn message
MyLogTesterB: this is a message that does not end in a newline when sent to the console... 
MyLogTesterB: continuation first line
MyLogTesterB: this is a message that does not end in a newline when sent to the console... 
MyLogTesterB: continuation second line
EOM
        actual_file_output = normalize_logfile(IO.read(@log_file))
        expect( actual_file_output ).to eq expected_file_output
      end
    end
  end

  describe 'count_down' do
    it 'should print generic countdown message to the console' do
      # exact match doesn't work in TravisCI
      expected = /\.\.\.2.*\.\.\.1.*\.\.\.0\n/
      expect{ MyLogTesterA.logger.count_down(2) }.to output(expected).to_stdout
      expect{ MyLogTesterB.new.logger.count_down(2) }.to output(expected).to_stdout
    end

    it 'should print customized countdown message to the console' do
      # exact match doesn't work in TravisCI
      expected = /\.\.\.Resuming in 2 seconds.*\.\.\.Resuming in 1 seconds.*\.\.\.Resuming in 0 seconds\n/
      expect{ MyLogTesterA.logger.count_down(2, 'Resuming in ', ' seconds') }.to output(expected).to_stdout
      expect{ MyLogTesterB.new.logger.count_down(2, 'Resuming in ', ' seconds') }.to output(expected).to_stdout
    end
  end
end

