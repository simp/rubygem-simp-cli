require 'simp/cli/defaults'
require 'simp/cli/logging'
require 'simp/cli/utils'

module Simp; end
class Simp::Cli; end

# This module provides standard console and file logging capabilities
# to a Command.
#
# A Command should include this module, call add_logging_command_options()
# to provide the user standard logger configuration options, and then
# call set_up_global_logger() to set up the logger prior to command
# processing.
module Simp::Cli::CommandLogger

  include Simp::Cli::Logging

  # Adds standard logging options to an OptionParser object
  # +opt_parser+: OptionParser object
  # +options+:    Hash that contains :log_basename, may contain
  #               :verbose and that will be updated, as appropriate,
  #               with :log_file and :verbose, when the command
  #               options are parsed
  #
  #   :log_basename = <Input> Default basename of the log file to
  #                   be opened.  Used in the help message.
  #   :log_file     = <Output> Fully qualified path to the log file
  #                   specified by --log-file option
  #   :verbose      = <Input and Output> Verbosity of console
  #                   messages. Set by --verbose and --quiet options.
  #                   Initial starting point can be pre-set.  If not
  #                   pre-set, the starting point will be assumed to
  #                   be NOTICE and above.
  #                   -1 = ERROR  and above
  #                    0 = NOTICE and above
  #                    1 = INFO   and above
  #                    2 = DEBUG  and above
  #                    3 = TRACE  and above  (developer debug)
  #
  # Raises RuntimeError if options is missing :log_basename
  #
  # CAUTION:  This ASSUMES specific options.  Any class that uses
  #    this must not have any conflicting options short/longnames.
  def add_logging_command_options(opt_parser, options)
    unless options[:log_basename]
      fail('add_logging_command_options: options Hash must contain :log_basename key')
    end
    options[:verbose] = 0 unless options.has_key?(:verbose)

    default_base = File.join(Simp::Cli::SIMP_CLI_HOME, options[:log_basename])
    opt_parser.on('-l', '--log-file FILE',
            'Log file. Defaults to',
            "#{default_base}.<timestamp>") do |file|
      options[:log_file] = File.expand_path(file)
    end

    #TODO Not allow -v and -q intermixed or the user may be surprised
    #     by subsequent console logging.
    opt_parser.on('-v', '--verbose',
            'Verbose console output (stacks). All details',
            'are recorded in the log file regardless.' ) do
      options[:verbose] += 1
    end

    opt_parser.on('-q', '--quiet',
            'Quiet console output.  Only errors are',
            'reported to the console. All details are',
            'recorded in the log file regardless.') do
      options[:verbose] = -1
    end

    opt_parser.on('--console-only',
                  'Suppress logging to file.') do
      options[:log_file] = :none
    end

  end

  # Set up the global logger
  #
  # Performs the following actions on the logger
  # - Opens log file with the specified log filename or one generated
  #   from a log basename and the start timestamp of the command.
  # - Configures levels of console logging and file logging.
  #   - File logging will always be at the DEBUG level and above
  #   - Console logging can be configured anywhere from ERROR
  #     and above down to TRACE and above.  TRACE messages are
  #     developer debug messages, i.e., messages not intended for
  #     users.
  #
  # +options+: Hash that contains :log_basename or :log_file, and, optionally,
  #           :start_time and :verbose keys. :log_file, :start_time, and
  #           :verbose will be set by this method, if missing.
  #
  #   :log_basename = Basename of the log file to be opened.  Used to
  #                   generate the name of the log file, when :log_file
  #                   is not specified.
  #   :log_file     = Fully qualified path to the log file or :none,
  #                   if file logging has been disabled
  #   :start_time   = Time the command processing started
  #   :verbose      = Verbosity of console messages.  Will be set to
  #                   NOTICE and above, if missing.
  #                   -1 = ERROR  and above
  #                    0 = NOTICE and above
  #                    1 = INFO   and above
  #                    2 = DEBUG  and above
  #                    3 = TRACE  and above  (developer debug)
  #
  # Raises RuntimeError if options does not contain either :log_basename
  #   or :log_file
  #
  def set_up_global_logger(options)
    options[:start_time] = Time.now unless options[:start_time]
    unless options[:log_file]
      unless options[:log_basename]
        fail('set_up_global_logger: options Hash must contain :log_basename or :log_file')
      end

      timestamp = Simp::Cli::Utils::timestamp_compact(options[:start_time])
      log_file = "#{options[:log_basename]}.#{timestamp}"
      options[:log_file] = File.join(Simp::Cli::SIMP_CLI_HOME, log_file)
    end

    unless (options[:log_file] == :none)
      FileUtils.mkdir_p(File.dirname(options[:log_file]))
      logger.open_logfile(options[:log_file])
    end

    options[:verbose] = 0 unless options[:verbose]
    case options[:verbose]
    when -1
      console_log_level = :error
    when 0
      console_log_level = :notice
    when 1
      console_log_level = :info
    when 2
      console_log_level = :debug
    else
      console_log_level = :trace # developer debug
    end
    file_log_level = :debug      # all but developer debug to file
    logger.levels(console_log_level, file_log_level)
  end

end
