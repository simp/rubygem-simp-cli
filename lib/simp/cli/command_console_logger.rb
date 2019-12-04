require 'simp/cli/defaults'
require 'simp/cli/logging'
require 'simp/cli/utils'

module Simp; end
class Simp::Cli; end

# This module provides standard console logging capabilities
# to a Command.
#
# A Command should include this module, call add_logging_command_options()
# to provide the user standard logger configuration options, and then
# call set_up_global_logger() to set up the logger prior to command
# processing.
module Simp::Cli::CommandConsoleLogger

  include Simp::Cli::Logging

  # Adds standard logging options to an OptionParser object
  # +opt_parser+: OptionParser object
  # +options+:    Hash that may contain :verbose setting that will be updated,
  #               as appropriate, based on --verbose or --quiet options.  If
  #               :verbose is pre-set it will be used as the verbosity starting
  #               point.  Otherwise, the starting point will be assumed to be
  #               NOTICE and above.
  #                 -1 = ERROR  and above
  #                  0 = NOTICE and above
  #                  1 = INFO   and above
  #                  2 = DEBUG  and above
  #                  3 = TRACE  and above  (developer debug)
  #
  # CAUTION:  This ASSUMES specific options.  Any class that uses
  #    this must not have any conflicting options short/longnames.
  def add_logging_command_options(opt_parser, options)
    options[:verbose] = 0 unless options.has_key?(:verbose)

    #TODO Not allow -v and -q intermixed or the user may be surprised
    #     by subsequent console logging.
    opt_parser.on('-v', '--verbose',
            'Verbose console output (stacks).' ) do
      options[:verbose] += 1
    end

    opt_parser.on('-q', '--quiet',
            'Quiet console output.  Only errors are',
            'reported to the console.' ) do
      options[:verbose] = -1
    end

  end

  # Set up the global logger
  #
  # Configures the console log level. This logging can be configured anywhere
  # from ERROR and above down to TRACE and above.  TRACE messages are developer
  # debug messages, i.e., messages not intended for users.
  #
  # +verbose+: Verbosity of console messages
  #              -1 = ERROR  and above
  #               0 = NOTICE and above
  #               1 = INFO   and above
  #               2 = DEBUG  and above
  #               3 = TRACE  and above  (developer debug)
  #
  def set_up_global_logger(verbose = 0)
    case verbose
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
    logger.levels(console_log_level)
  end

end
