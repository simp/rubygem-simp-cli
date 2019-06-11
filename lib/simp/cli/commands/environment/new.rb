# frozen_string_literal: true

require 'simp/cli/commands/command'
require 'simp/cli/environment/omni_env_controller'
require 'simp/cli/command_logger'
require 'yaml'

# Cli command to create a new Extra/Omni environment
#
# TODO: As more `simp environment` sub-commands are added, a lot of this code
#      could probably be abstracted into a common class or mixin
class Simp::Cli::Commands::Environment::New < Simp::Cli::Commands::Command

  include Simp::Cli::CommandLogger

  TYPES=[:puppet, :secondary, :writable]

  # @return [String] description of command
  def self.description
    'Create a new SIMP "Extra" (default) or "omni" environment'
  end

  # Run the command's `--help` strategy
  def help
    parse_command_line(['--help'])
  end

  # Parse command-line options for this simp command
  # @param args [Array<String>] ARGV-style args array
  def parse_command_line(args)
    # TODO: simp cli should read a config file that can override these defaults
    # these options (preferrable mimicking cmd-line args)
    options = Simp::Cli::Utils.default_simp_env_config
    options[:action] = :create
    options[:start_time] = Time.now
    options[:log_basename] = 'simp_env_new.log'

    ####### IMPORTANT
    # This is EXPLICITLY set to INFO, so that, by default, when
    # 'simp environment fix' is called, details are sent to the
    # console, but NOT sent to the console when the corresponding
    # code is used within 'simp config'.
    options[:verbose] = 1 # -1 = ERROR  and above
                          #  0 = NOTICE and above
                          #  1 = INFO   and above
                          #  2 = DEBUG  and above
                          #  3 = TRACE  and above

    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp environment new [options]'
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        Usage:

          simp environment new ENVIRONMENT [OPTIONS]

        By default, this command will:

          * create a new environment (–-skeleton)
          * raise an error if an environment directory already exists

        It can create a complete SIMP omni-environment with --puppet-env

        Examples:

             # Create a skeleton new development environment
             simp environment new development

             # Link staging's Secondary and Writable env dirs to production
             simp environment new staging --link production

             # Create a separate copy of production (will diverge over time)
             simp environment new newprod --copy production

             # Create new omni environment
             simp environment new local_prod --puppetfile

        Options:

      HELP_MSG

      opts.on('--skeleton',
              '(default) Generate environments from skeleton templates.',
              'Implies --puppetfile') do
                TYPES.each do |type|
                  options[:types][type][:strategy]    = :skeleton
                end
                options[:types][:puppet][:puppetfile_generate] = true
              end

      opts.on('--copy ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Copy assets from ENVIRONMENT') do |src_env|
                TYPES.each do |type|
                  options[:types][type][:strategy] = :copy
                  options[:types][type][:src_env]  = src_env
                end
              end

      opts.on('--link ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Symlink Secondary and Writable environment directories',
              'to ENVIRONMENT.  If --puppet-env is set, the Puppet',
              'environment will --copy.') do |src_env|
                TYPES.each do |type|
                  options[:types][type][:strategy] = :link
                  options[:types][type][:src_env]  = src_env
                end
                options[:types][:puppet][:strategy] = :copy
              end

      opts.on('--[no-]puppetfile',
              'Generate Puppetfiles in Puppet env directory',
              '  * `Puppetfile` will only be created if missing',
              '  * `Puppetfile.simp` will be generated from RPM/',
              '  * Implies `--puppet-env`') do |v|
        options[:types][:puppet][:enabled] = true if (options[:types][:puppet][:puppetfile_generate] = v)
      end

      opts.on('--[no-]puppetfile-install',
              'Automatically deploys Puppetfile in Puppet environment',
              'directory after creating it',
              '  * Implies `--puppet-env`',
              '  * Does NOT imply `--puppetfile`') do |v|
        options[:types][:puppet][:enabled] = true if (options[:types][:puppet][:puppetfile_install] = v)
      end

      opts.on('--[no-]puppet-env',
              'Includes Puppet environment when `--puppet-env`',
              '(default: --no-puppet-env)') { |v| options[:types][:puppet][:enabled] = v }

      opts.on('--[no-]secondary-env',
              'Includes Secondary environment when `--secondary-env`',
              '(default: --secondary-env)') { |v| options[:types][:secondary][:enabled] = v }

      opts.on('--[no-]writable-env',
              'Includes writable environment when `--writable-env`',
              '(default: --writable-env)') { |v| options[:types][:writable][:enabled] = v }

      opts.separator ''

      add_logging_command_options(opts, options)

      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end
    end
    opt_parser.parse!(args)
    options
  end

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    options = parse_command_line(args)
    return if @help_requested

    action = options.delete(:action)

    fail(Simp::Cli::ProcessingError, "ERROR: 'ENVIRONMENT' is required.") if args.empty?

    env = args.shift

    unless Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME.match?(env)
      fail(
        Simp::Cli::ProcessingError,
        "ERROR: '#{env}' is not an acceptable environment name"
      )
    end

    set_up_global_logger(options)

    unless options[:verbose] < 0
      logger.say("Actions will be logged to\n  #{options[:log_file]}\n".bold)
    end
    logger.debug("Environment creation options:\n#{options.to_yaml}\n")

    omni_controller = Simp::Cli::Environment::OmniEnvController.new(options, env)
    omni_controller.send(action)

    unless options[:verbose] < 0
      logger.say( "\n" + "Detailed log written to #{options[:log_file]}".bold )
    end
  end

end
