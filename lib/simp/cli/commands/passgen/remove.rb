require 'simp/cli/commands/command'
require 'simp/cli/passgen/command_common'

class Simp::Cli::Commands::Passgen::Remove < Simp::Cli::Commands::Command

  include Simp::Cli::Passgen::CommandCommon

  def initialize
    @opts = {
      :env          => DEFAULT_PUPPET_ENVIRONMENT,
      :backend      => nil, # simpkv backend
      :folder       => nil, # passgen sub-folder in simpkv
      :force_remove => DEFAULT_FORCE, # whether to remove without prompting
      :names        => [],  # names of passwords to remove
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
    "Remove 'simplib::passgen' passwords"
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

    remove_passwords(manager, @opts[:names], @opts[:force_remove])
  end

  #####################################################
  # Custom methods
  #####################################################

  # @param args Command line arguments
  #
  # @raise OptionsParser::ParseError upon any options parsing or validation
  #   failure
  # @raise Simp::Cli::ProcessingError if the list of passwords to remove is
  #   missing from args
  #
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################
    #
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp passgen remove [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}.

        #{AUTO_LOCATION_INFO}
        USAGE:
          simp passgen remove -h
          simp passgen remove NAME1,NAME2,... [-e ENV] [--[no-]force] \\
            [--backend BACKEND|-d DIR] [-v|-q]

        EXAMPLES:
          # Remove specific passwords in the production environment.
          simp passgen remove app1_admin,app2_auth

          # Remove specific passwords in the test environment without
          # prompting to confirm removal.
          simp passgen remove app1_admin,app2_auth -e test --force

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
          "will be applied. Defaults to '#{@opts[:env]}'.") do |env|
        @opts[:env] = env
      end

      opts.on('--[no-]force',
          'Remove passwords without prompting user to',
          'confirm. When disabled, the user will be',
          'prompted to confirm the removal for each',
          'password. Defaults to ' +
          "#{translate_bool(@opts[:env])}.") do |force|
        @opts[:force_remove] = force
      end

      add_logging_command_options(opts, @opts)

      opts.on('-h', '--help', 'Print this message.') do
        puts opts
        @help_requested = true
      end
    end

    remaining_args = opt_parser.parse!(args)

    unless @help_requested
      if remaining_args.empty?
        err_msg = 'Password names are missing from command line'
        raise Simp::Cli::ProcessingError, err_msg
      else
        @opts[:names] = remaining_args[0].split(',').sort
      end
    end
  end

  # Remove a list of passwords
  #
  # @param manager Password manager to use to retrieve password info
  # @param names Array of names(keys) of passwords to remove
  # @param force_remove Whether to remove password files without prompting
  #   the user to verify the removal operation
  #
  # @raise Simp::Cli::ProcessingError if unable remove all passwords
  #
  def remove_passwords(manager, names, force_remove)
    errors = []
    names.each do |name|
      remove = force_remove
      unless force_remove
        prompt = "Are you sure you want to remove all info for '#{name}'?".bold
        remove = Simp::Cli::Utils::yes_or_no(prompt, false)
      end

      if remove
        # space at end tells logger to omit <CR>, so spinner+done are on same
        # line
        logger.notice("Processing '#{name}' in #{manager.location}... ")
        begin
          Simp::Cli::Utils::show_wait_spinner {
            manager.remove_password(name)
          }
          logger.notice('done.')
          logger.notice("  Removed '#{name}'")
        rescue Exception => e
          logger.notice('done.')
          logger.notice("  Skipped '#{name}'")
          errors << "'#{name}': #{e}"
        end
      else
        logger.notice("Skipped '#{name}' in #{manager.location}")
      end

      logger.notice
    end

    unless errors.empty?
      err_msg = "Failed to remove #{errors.length} out of #{names.length}" +
        " passwords in #{manager.location}:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end
end
