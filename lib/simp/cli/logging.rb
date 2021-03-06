require 'highline/import'
HighLine.colorize_strings

require 'logger'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Logging

  def self.logger
    @logger ||= Simp::Cli::Logging::Logger.new
  end

  # for class methods of class including this module
  def self.included(base)
    class << base
      def logger
        Simp::Cli::Logging.logger
      end
    end
  end

  # for instance methods of class including this module
  def logger
    Simp::Cli::Logging.logger
  end

  # Class to provide a console and optional log file logging
  #
  # Integrates ::Logger and ::Highline
  class Logger
    # Only way to get the log levels we want is to create a
    # set of custom severities as Integers. Users will use
    # the severity symbols in this table or helper methods
    # provided.
    SEVERITY_TO_NUM = {
      :trace  => ::Logger::FATAL+10,
      :debug  => ::Logger::FATAL+11,
      :info   => ::Logger::FATAL+12,
      :notice => ::Logger::FATAL+13,
      :warn   => ::Logger::FATAL+14,
      :error  => ::Logger::FATAL+15,
      :fatal  => ::Logger::FATAL+16
    }

    def initialize
      @file          = nil
      @file_logger   = nil
      @console_level = SEVERITY_TO_NUM[:error]
      @file_level    = SEVERITY_TO_NUM[:error]
    end

    def open_logfile(file)
      @file.close if @file
      @file = File.new(file, 'w')  # overwrite existing file
      @file.sync = true            # flush after every write
      @file_logger = ::Logger.new(@file)
      @file_logger.formatter = proc do |severity, datetime, progname, msg |
        timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
        "#{timestamp}: #{msg}\n"
      end
    end

    def levels(console_level=:info, file_level=:debug)
      @console_level = SEVERITY_TO_NUM[console_level]
      @file_level = SEVERITY_TO_NUM[file_level]
      @file_logger.level = @file_level if @file_logger
    end

    def trace(*args)
      log_and_say(:trace, *args)
    end

    def debug(*args)
      log_and_say(:debug, *args)
    end

    def info(*args)
      log_and_say(:info, *args)
    end

    def notice(*args)
      log_and_say(:notice, *args)
    end

    def warn(*args)
      log_and_say(:warn, *args)
    end

    def error(*args)
      log_and_say(:error, *args)
    end

    def fatal(*args)
      log_and_say(:fatal, *args)
    end

    # log plain text to a log file and print formatted
    # text to the console using HighLine formatting
    #
    # level = :trace, :debug, :info, :notice, :warn, :error, :fatal
    # args = sequence of alternating message part and corresponding
    #   format specifications, where each message part is a string and
    #   each format specification is either nil (no formatting) or an
    #   array contains 0 or more constants corresponding to HighLine
    #   formatting options.
    #
    # NOTE:  When the final part of a message ends in a ' ' character,
    # HighLine suppresses the newline when the message is sent to the
    # console.
    #
    # Examples,
    #
    # log_and_say(:debug, 'this is an unformatted text message')
    # log_and_say(:warn, 'this is a single-part, formatted text message', [:BOLD, :RED])
    # log_and_say(:info, 'this is a', nil, ' multi-part ', [:BOLD], 'formatted text message')
    # log_and_say(:info, 'this is a message that does not end in a newline when sent to the console ')
    # log_and_say(:notice, 'this is a message already formatted'.bold)
    # log_and_say(:error, 'this is a', [], ' message ', [:RED], 'that does not end in a newline when sent to the console ')
    #
    def log_and_say(level, *args)
      level_num = SEVERITY_TO_NUM[level]
      plain_message, formatted_message = create_message_strings(*args)
      if @file_logger
        plain_message.split("\n").each { |msg| @file_logger.log(level_num, msg) }
      end

      unless level_num < @console_level
        say( formatted_message )
      end
    end

    # pause for the specified number of seconds, printing a countdown
    # message to the console every second
    # +pause_seconds+: Number of seconds to pause
    # +pre_txt+: Text to prepend to the current count in the console message
    # +post_txt+: Text to append to the current count in the console message
    def count_down(pause_seconds, pre_txt='', post_txt='')
      count = pause_seconds
      max_len = count.to_s.size
      while count > 0
        $stdout.printf("...#{pre_txt}%#{max_len}d#{post_txt}", count)
        sleep(1)
        $stdout.write("\r")
        count -= 1
      end
      $stdout.printf("...#{pre_txt}%#{max_len}d#{post_txt}\n", 0)
    end

   # pause log output to allow message of
   # message_level to be viewed on the console
    def pause(message_level, pause_seconds)
      unless SEVERITY_TO_NUM[message_level] < @console_level
        sleep pause_seconds
      end
    end


    def format_console_message(message, font_options)
      options = ''
      if font_options.nil? or font_options.empty?
        formatted_message = message
      else
        options = ", #{font_options.join(', ')}"
        extra = ''
        adjusted_message = message.dup
        if adjusted_message[-1] == ' '
          # HighLine interprets a space at the end of a message to mean
          # that an ending <CR> should be omitted. We need to maintain
          # this in our formatted message.
          adjusted_message.chop!
          extra = ' '
        end
        # since we are using {} as the string delimiter, make sure we've escaped
        # any {} in the message
        adjusted_message.gsub!('{', '\{')
        adjusted_message.gsub!('}', '\}')
        formatted_message = "<%= color(%q{#{adjusted_message}}#{options}) %>#{extra}"

      end
      formatted_message
    end

    def create_message_strings(*args)
      plain_message = ''
      formatted_message = ''
      args.each_slice(2) do |message_part_tuple|
        message_part = message_part_tuple[0]
        font_options = message_part_tuple[1]
        plain_message += message_part
        formatted_message += format_console_message(message_part, font_options)
      end
      if formatted_message[-1] != ' '
        formatted_message += "\n"
      end
      # some messages come in already formatted, so be sure to remove it
      [plain_message.uncolor, formatted_message]
    end

    def say(message)
      HighLine::say(message)
    end
  end

end
