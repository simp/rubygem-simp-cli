require 'simp/cli/commands/command'
require 'simp/cli/passgen/command_common'

class Simp::Cli::Commands::Passgen::List < Simp::Cli::Commands::Command

  include Simp::Cli::Passgen::CommandCommon

  def initialize
    @opts = {
      :env          => DEFAULT_PUPPET_ENVIRONMENT,
      :backend      => nil, # simpkv backend
      :folder       => nil, # passgen sub-folder in simpkv
      :password_dir => nil, # fully qualified path to a legacy passgen dir
      :verbose      => 0    # Verbosity of console output:
      #                        -1 = ERROR  and above
      #                         0 = NOTICE and above
      #                         1 = INFO   and above
      #                         2 = DEBUG  and above
      #                         3 = TRACE  and above  (developer debug)
    }
  end

  #####################################################
  # Simp::Cli::Commands::Command API methods
  #####################################################
  #
  def self.description
    "List names of 'simplib::passgen' passwords"
  end

  def help
    parse_command_line( [ '--help' ] )
  end

  # @param args Command line options
  def run(args)
    parse_command_line(args)
    return if @help_requested

    # set verbosity threshold for console logging
    set_up_global_logger(@opts[:verbose])

    # space at end tells logger to omit <CR>, so spinner+done are on same line
    logger.notice("Initializing for environment '#{@opts[:env]}'... ")
    manager = nil
    Simp::Cli::Utils::show_wait_spinner {
      # construct the correct manager to do the work based on simplib version
      manager = get_password_manager(@opts)
    }
    logger.notice('done.')

    show_name_list(manager)
  end

  #####################################################
  # Custom methods
  #####################################################

  # @param args Command line arguments
  #
  # @raise OptionsParser::ParseError upon any options parsing or validation
  #   failure
  #
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################
    #
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp passgen list [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        #{AUTO_LOCATION_INFO}
        USAGE:
          simp passgen list -h
          simp passgen list [-e ENV] [--folder FOLDER] [--backend BACKEND] [-v|-q]
          simp passgen list [-e ENV] [-d DIR] [-v|-q]

        EXAMPLES:
          # Show a list of the password names in the production environment
          simp passgen list

          # Show a list of the password names in the dev environment
          simp passgen list -e dev

        OPTIONS:
      HELP_MSG

      opts.on('--backend BACKEND',
              'Specific simpkv backend to use for',
              'passwords. Rarely needs to be set.',
              'Overrides the appropriate backend',
              'for the environment.') do |backend|
        @opts[:backend] = backend
      end

      opts.on('-d', '--dir DIR',
              'Fully qualified path to a legacy password',
              'store. Rarely needs to be set. Overrides',
              'the directory for the environment.') do |dir|
        @opts[:password_dir] = dir
      end

      opts.on('-e', '--env ENV',
              'Puppet environment to which the operation',
              "will be applied. Defaults to #{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      opts.on('--folder FOLDER',
              'Sub-folder in which to find password names',
              'in a simpkv key/value store. Defaults to the',
              'top-level folder for simplib::passgen.' ) do |folder|
        @opts[:folder] = folder
      end

      add_logging_command_options(opts, @opts)

      opts.on('-h', '--help', 'Print this message.') do
        puts opts
        @help_requested = true
      end
    end

    opt_parser.parse!(args)
  end

  # Print the list of passwords found to the console
  #
  # @param manager Password manager to use to retrieve password info
  #
  # @raise Simp::Cli::ProcessingError if retrieval of password list fails
  #
  def show_name_list(manager)
    # space at end tells logger to omit <CR>, so spinner+done are on same line
    logger.notice('Retrieving password names... ')
    begin
      names = nil
      Simp::Cli::Utils::show_wait_spinner {
        names = manager.name_list
      }
      logger.notice('done.')

      logger.say("\n")
      if names.empty?
        logger.say("No passwords found in #{manager.location}")
      else
        title = "#{manager.location} Password Names"
        logger.say(title)
        logger.say('='*title.length)
        logger.say(names.join("\n"))
      end
      logger.notice
    rescue Exception => e
      err_msg = "List for #{manager.location} failed: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end
end
