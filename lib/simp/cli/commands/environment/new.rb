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
    # NOTE:  This does not do a deep copy of the Hash.  May impact unit tests.
    options = Simp::Cli::Utils.default_simp_env_config.dup
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

          * create a new SIMP Omni environment (--skeleton)

          * raise an error if an environment directory already exists

        Examples:

             # Generate a new Omni environment skeleton (default)
             #   * Creates skeleton Puppet and Secondary environment directories
             #   * Generates new Puppetfile and Puppetfile.simp files in the Puppet
             #     environment
             #     - see: `simp puppetfile generate --help`
             #
             simp environment new development

             # Generates a new Omni environment
             #   * Creates a new Omni environment skeleton
             #   * Deploys modules in the generated Puppetfiles using
             #     `r10k puppetfile install`
             simp environment new dev2 --puppetfile-install

             # Generate just the directory skeletons for a new Omni
             # environment
             simp environment new dev3 --no-puppetfile-gen

             # Create a new Omni environment with a copy of an existing
             # environment's Puppet environment and links to that
             # environment's Secondary and Writable env dirs
             simp environment new staging --link production

             # Create a separate copy of an existing environment
             # (will diverge over time)
             simp environment new new_prod --copy production

      HELP_MSG

      opts.separator('PRIMARY OPTIONS (mutually exclusive):')
      opts.on('--skeleton',
               '(default) Generate environments from',
               'skeleton templates and generate',
               'Puppetfiles in the Puppet environment',
               "that reference SIMP's local module Git",
               'repositories.') do
         TYPES.each do |type|
           options[:types][type][:strategy]    = :skeleton
         end

         unless ( args.include?('--no-puppet-env') ||
                 args.include?('--no-puppetfile-gen') )
           options[:types][:puppet][:puppetfile_generate] = true
         end
      end

      opts.on('--copy SRC_ENV', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Copy full Omni environment from SRC_ENV.') do |src_env|
        TYPES.each do |type|
          options[:types][type][:strategy] = :copy
          options[:types][type][:src_env]  = src_env
        end
      end

      opts.on('--link SRC_ENV', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Symlink Secondary and Writable environment',
              "directories to SRC_ENV and copy OTHER_ENV's",
              'Puppet environment directory.') do |src_env|
        TYPES.each do |type|
          options[:types][type][:strategy] = :link
          options[:types][type][:src_env]  = src_env
        end
        options[:types][:puppet][:strategy] = :copy
      end

      opts.separator('MODIFIER OPTIONS:')
      opts.on('--[no-]puppetfile-gen',
              'Generate Puppetfiles in the Puppet env',
              'directory.',
              '  * `Puppetfile` includes `Puppefile.simp`.',
              '  * `Puppetfile.simp` is generated from',
              "    SIMP's local, module Git repositories.",
              '  * Enabled by default for `--skeleton`.',
              '  * Only generates `Puppetfile` if it',
              '    does not already exist.') do |v|
        options[:types][:puppet][:puppetfile_generate] = v
      end

      opts.on('--puppetfile-install',
              'Automatically deploy an existing Puppetfile',
              'in the Puppet environment.',
              ' * Can be used with `--puppetfile-gen`',
              '   to create the Puppetfile first.') do |v|
        options[:types][:puppet][:puppetfile_install] = true
      end

      opts.on('--[no-]puppet-env',
              'Include the Puppet environment.',
              'Enabled by default.') do |v|
        options[:types][:puppet][:enabled] = v
      end

      opts.on('--[no-]secondary-env',
              'Include the Secondary environment.',
              'Enabled by default.') do |v|
        options[:types][:secondary][:enabled] = v
      end

      opts.on('--[no-]writable-env',
              'Include the Writable environment.',
              'Enabled by default.') do |v|
        options[:types][:writable][:enabled] = v
      end

      opts.separator('OTHER OPTIONS:')

      add_logging_command_options(opts, options)

      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end
    end

    unless STRATEGY_ARGS.any?{ |x| args.include?(x) }
      say "TRACE: === default: add --skeleton".cyan if options[:verbose] > 2
      args.unshift('--skeleton')
    end

    fail_on_multiple_strategies(args)
    remaining_args = opt_parser.parse(args)

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

    unless (options[:verbose] < 0) || (options[:log_file] == :none)
      logger.say("Actions will be logged to\n  #{options[:log_file]}\n".bold)
    end
    logger.debug("Environment creation options:\n#{options.to_yaml}\n")

    action = options.delete(:action)
    omni_controller = Simp::Cli::Environment::OmniEnvController.new(options, env)
    omni_controller.send(action)

    unless (options[:verbose] < 0) || (options[:log_file] == :none)
      logger.say( "\n" + "Detailed log written to #{options[:log_file]}".bold )
    end
  end

end
