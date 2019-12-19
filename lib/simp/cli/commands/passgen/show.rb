require 'simp/cli/commands/command'
require 'simp/cli/passgen/command_common'

class Simp::Cli::Commands::Passgen::Show < Simp::Cli::Commands::Command

  include Simp::Cli::Passgen::CommandCommon

  DEFAULT_DETAILS = false  # whether to print out all available password info

  def initialize
    @opts = {
      :env          => DEFAULT_PUPPET_ENVIRONMENT,
      :backend      => nil, # libkv backend
      :details      => DEFAULT_DETAILS,
      :folder       => nil, # passgen sub-folder in libkv
      :names        => [],  # names of passwords to show
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
    "Show 'simplib::passgen' passwords and other stored attributes"
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

    show_password_info(manager, @opts[:names], @opts[:details])
  end

  #####################################################
  # Custom methods
  #####################################################

  # @return Brief information to be logged
  # @param results Hash of results for individual password names
  def format_brief_results(results)
    lines = []
    results.each do |name, info|
      lines << "Name: #{name}"
      if info == :skipped
        lines << '  Skipped'
      else
        lines << "  Current:  #{info['value']['password']}"
        unless info['metadata']['history'].empty?
          lines << "  Previous: #{info['metadata']['history'][0][0]}"
        end
      end
      lines << ''
    end

    lines.join("\n")
  end

  # @return Detailed information to be logged
  # @param results Hash of results for individual password names
  def format_detailed_results(results)
    lines = []
    results.each do |name, info|
      lines << "Name: #{name}"
      if info == :skipped
        lines << '  Skipped'
      else
        lines << "  Password:     #{info['value']['password']}"
        lines << "  Salt:         #{info['value']['salt']}"
        lines << "  Length:       #{info['value']['password'].length}"

        if info['metadata'].key?('complexity')
          lines << "  Complexity:   #{info['metadata']['complexity']}"
        end

        if info['metadata'].key?('complex_only')
          lines << "  Complex-Only: #{info['metadata']['complex_only']}"
        end

        unless info['metadata']['history'].empty?
          lines << '  History:'
          info['metadata']['history'].each do |password,salt|
            lines << "    Password: #{password}"
            lines << "    Salt:     #{salt}"
          end
        end
      end
      lines << ''
    end

    lines.join("\n")
  end

  # @return formatted results
  # @param results Hash of results for individual password names
  # @param details Whether to display all available password information
  #
  def format_results(results, details)
    if details
      format_detailed_results(results)
    else
      format_brief_results(results)
    end
  end


  # @param args Command line arguments
  #
  # @raise OptionsParser::ParseError upon any options parsing or validation
  #   failure
  # @raise Simp::Cli::ProcessingError if the list of passwords to show is
  #   missing from args
  #
  def parse_command_line(args)
    ###############################################################
    # NOTE TO MAINTAINERS: The help message has been explicitly
    # formatted to fit within an 80-character-wide console window.
    ###############################################################
    #
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp passgen show [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}.

        #{AUTO_LOCATION_INFO}
        USAGE:
          simp passgen show -h
          simp passgen show NAME1,NAME2,... [-e ENV] [--[no-]details] \\
            [--backend BACKEND|-d DIR] [-v|-q]

        EXAMPLES:
          # Show basic password info for specific passwords in the production env
          simp passgen show app1_admin,app2_auth

          # Show all available password info for specific passwords in the test env
          simp passgen show app1_admin,app2_auth -e test --details

        OPTIONS:
      HELP_MSG

      opts.on('--backend BACKEND',
              'Specific libkv backend to use for',
              'passwords. Rarely needs to be set.',
              'Overrides the appropriate backend',
              'for the environment.') do |backend|
        @opts[:backend] = backend
      end

      opts.on('--[no-]details',
              'Whether to show all available details.',
              'When disabled, only the current and',
              'previous password values are shown. ',
              "Defaults to #{translate_bool(@opts[:details])}.") do |details|
        @opts[:details] = details
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

  # Prints password info to the console.
  #
  # For each password name, prints its current value, and when present, its
  # previous value.
  #
  # @param manager Password manager to use to retrieve password info
  # @param names Names of passwords to be printed
  # @param details Whether to show all available details
  #
  # @raise Simp::Cli::ProcessingError if unable to retrieve password
  #   info for all names
  #
  def show_password_info(manager, names, details)
    # space at end tells logger to omit <CR>, so spinner+done are on same line
    logger.notice('Retrieving password information... ')
    results = {}
    errors = []
    Simp::Cli::Utils::show_wait_spinner {
      names.each do |name|
        begin
          info = manager.password_info(name)
          results [ name ] = info
        rescue Exception => e
          results [ name ] = :skipped
          errors << "'#{name}': #{e}"
        end
      end
    }
    logger.notice('done.')

    formatted_results = format_results(results, details)

    logger.say("\n")
    title = "#{manager.location} Passwords"
    logger.say(title)
    logger.say('='*title.length)
    logger.say(formatted_results)

    unless errors.empty?
      err_msg = "Failed to retrieve #{errors.length} out of #{names.length}" +
        " passwords in #{manager.location}:\n  #{errors.join("\n  ")}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end
end
