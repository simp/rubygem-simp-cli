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
  STRATEGY_ARGS=['--skeleton', '--copy', '--link']

  # @return [String] description of command
  def self.description
    'Create a new SIMP "Omni" environment (or a subset)'
  end

  # Run the command's `--help` strategy
  def help
    parse_command_line(['--help'])
  end

  def fail_on_multiple_strategies(args)
    if args.count{ |x| STRATEGY_ARGS.include?(x) } > 1
      fail(
        Simp::Cli::ProcessingError,
        "ERROR: Cannot specify more than one of: #{STRATEGY_ARGS.join(', ')}"
      )
    end
  end

  # Parse command-line options for this simp command
  # @param args [Array<String>] ARGV-style args array
  def parse_command_line(args)
    # TODO: simp cli should read a config file that can override these defaults
    # these options (preferrably mimicking cmd-line args)
    default_options = Simp::Cli::Utils.default_simp_env_config
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

          * create a new SIMP Omni environment (–-skeleton)

          * raise an error if an environment directory already exists

        Examples:

             # Generate a new Omni environment directory from skeleton (default)
             #
             #   * Creates skeleton Puppet and Secondary environment directories
             #   * Generates new Puppetfile and Puppetfile.simp
             #     - see: `simp puppetfile generate --help`
             #   * Runs `r10k puppetfile install` in `local_prod` Puppet env dir
             #
             simp environment new development

             # Link staging's Secondary and Writable env dirs to production
             simp environment new staging --link production

             # Create a separate copy of production (will diverge over time)
             simp environment new new_prod --copy production

             # Create + deploy new `local_prod` Omni environment from skeleton
             simp environment new local_prod --no-puppetenv

        Options:

      HELP_MSG

      opts.on('--skeleton',
               '(default) Generate environments from skeleton templates.',
               'Implies `--puppetfile` when `--puppet-env` is enabled.') do
         say "=== do --skeleton".yellow if options[:debug]
         TYPES.each do |type|
           options[:types][type][:strategy]    = :skeleton
         end
         unless(args.include?('--no-puppet-env'))
           unless(args.include?('--no-puppetfile'))
             say "=== do --skeleton: add --puppetfile".cyan if options[:debug]
             args << '--puppetfile'
           end
         end
      end

      opts.on('--copy ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Copy assets from ENVIRONMENT') do |src_env|
        say "=== do --copy #{src_env}".yellow if options[:debug]
        TYPES.each do |type|
          options[:types][type][:strategy] = :copy
          options[:types][type][:src_env]  = src_env
        end
      end

      opts.on('--link ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Symlink Secondary and Writable environment directories',
              'to ENVIRONMENT.  If --puppet-env is set, the Puppet',
              'environment will --copy.') do |src_env|
        say "=== do --link #{src_env}".yellow if options[:debug]
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
        say "=== do --puppetfile = #{v}".yellow if options[:debug]
        options[:types][:puppet][:puppetfile_generate] = v
        unless(args.include?('--no-puppet-env'))
          say "===    --puppetfile: add --puppet-env".cyan if options[:debug]
          args << '--puppet-env' if v
        end
      end

      opts.on('--[no-]puppetfile-install',
              'Automatically deploys Puppetfile in Puppet environment',
              'directory after creating it',
              '  * Implies `--puppet-env`',
              '  * Does NOT imply `--puppetfile`') do |v|
        say "=== do --puppetfile-install = #{v}".yellow if options[:debug]
        options[:types][:puppet][:puppetfile_install] = v
        unless(args.include?('--no-puppet-env'))
          if v
            say "===    --puppetfile-install: add --puppet-env".cyan if options[:debug]
            args << '--puppet-env'
          end
        end
      end

      opts.on('--[no-]puppet-env',
              'Includes Puppet environment when `--puppet-env`',
              '(defaults:',
              '  when `--skeleton` (default): --puppet-env',
              '  when `--copy` or `--link`:   --no-puppet-env',
              ')') do |v|
                say "=== do --puppet-env = #{v}".yellow if options[:debug]
                options[:types][:puppet][:enabled] = v
              end

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

    orig_args = args.dup
    # implications
    unless STRATEGY_ARGS.any?{ |x| args.include?(x) }
      say "=== default: add --skeleton".cyan if options[:debug]
      args << '--skeleton'
    end
    fail_on_multiple_strategies(args)
    remaining_args = opt_parser.parse(args)
    if options[:debug]
      say "original args: '#{orig_args}'".cyan
      say "final args: '#{args}'".bold
    end

    [options, remaining_args]
  end

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    options, remaining_args = parse_command_line(args)

    return if @help_requested

    fail(Simp::Cli::ProcessingError, "ERROR: 'ENVIRONMENT' is required.") if remaining_args.empty?
    env = remaining_args.shift
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

    action = options.delete(:action)
    omni_controller = Simp::Cli::Environment::OmniEnvController.new(options, env)
    omni_controller.send(action)

    unless options[:verbose] < 0
      logger.say( "\n" + "Detailed log written to #{options[:log_file]}".bold )
    end
  end

end
