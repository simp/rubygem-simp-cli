require 'simp/cli/commands/command'
require 'simp/cli/passgen/command_common'

class Simp::Cli::Commands::Passgen::Envs < Simp::Cli::Commands::Command

  include Simp::Cli::Passgen::CommandCommon

  def initialize
    @opts = {
      :verbose => 0  # Verbosity of console output:
      #               0 = NOTICE and above
      #               1 = INFO   and above
      #               2 = DEBUG  and above
      #               3 = TRACE  and above  (developer debug)
    }
  end

  #####################################################
  # Simp::Cli::Commands::Command API methods
  #####################################################
  #
  def self.description
    "List environments that may have 'simplib::passgen' passwords"
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

    show_environment_list
  end

  #####################################################
  # Custom methods
  #####################################################

  # @return Hash Puppet environments in which simp-simplib has been installed
  #   - key is the environment name
  #   - value is the version of simp-simplib
  #
  # @raise Simp::Cli::ProcessingError if `puppet module list` fails
  #   for any Puppet environment
  #
  def find_valid_environments
    # grab the environments path from the production env puppet master config
    environments_dir = Simp::Cli::Utils.puppet_info[:config]['environmentpath']
    environments = Dir.glob(File.join(environments_dir, '*'))
    environments.map! { |env| File.basename(env) }

    # only keep environments that have simplib installed
    env_info = {}
    environments.sort.each do |env|
      simplib_version = get_simplib_version(env)
      env_info[env] =simplib_version unless simplib_version.nil?
    end

    env_info
  end

  # @param args Command line arguments
  #
  # @raise OptionsParser::ParseError upon any options parsing or validation
  #   failure
  #
  def parse_command_line(args)
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp passgen envs [options]'
      opts.separator <<~HELP_MSG

        #{self.class.description}

        USAGE:
          simp passgen envs -h
          simp passgen envs [-v|-q]

        OPTIONS:
      HELP_MSG

      add_logging_command_options(opts, @opts)

      opts.on('-h', '--help', 'Print this message.') do
        puts opts
        @help_requested = true
      end
    end

    opt_parser.parse!(args)
  end

  # Prints to the console the list of Puppet environments for which
  # simp-simplib is installed
  #
  # @raise Simp::Cli::ProcessingError if `puppet module list` fails
  #   for any Puppet environment
  #
  def show_environment_list
    # space at end tells logger to omit <CR>, so spinner+done are on same line
    logger.notice('Looking for environments with simp-simplib installed... ')
    valid_envs = nil
    Simp::Cli::Utils::show_wait_spinner {
      valid_envs = find_valid_environments
    }
    logger.notice('done.')

    logger.say("\n")
    if valid_envs.empty?
      logger.say('No environments with simp-simplib installed were found.')
    else
      title = 'Environments'
      logger.say(title)
      logger.say('='*title.length)
      logger.say( valid_envs.keys.sort.join("\n"))
    end
    logger.notice
  end
end
