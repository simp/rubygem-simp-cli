module TestUtils

  # Mock implementation of Simp::Cli::Logger
  # Saves off messages that can be retrieved
  class MockLogger
    attr_reader :log_file, :console_level, :file_level
    attr_reader :messages

    def initialize
      @messages = {
        :trace  => [],
        :debug  => [],
        :info   => [],
        :notice => [],
        :warn   => [],
        :error  => [],
        :fatal  => [],
        :say    => []
     }
    end

    def open_logfile(file)
      @log_file = file
    end

    def levels(console_level=:info, file_level=:debug)
      @console_level = console_level
      @file_level = file_level
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

    def log_and_say(level, *args)
      @messages[level] << [ *args ]
    end

    def count_down(pause_seconds, pre_txt='', post_txt='')
    end

    def pause(message_level, pause_seconds)
    end

    def format_console_message(message, font_options)
      message
    end

    def create_message_strings(*args)
      args.join('  ')
    end

    def say(message)
      @messages[:say] << message
    end
  end
end

