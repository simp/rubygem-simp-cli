# frozen_string_literal: true

require 'simp/cli/commands/command'
require 'simp/cli/environment/omni_env_controller'

# Cli command to create a new Extra/Omni environment
#
# TODO: As more `simp environment` sub-commands are added, a lot of this code
#      could probably be abstracted into a common class or mixin
class Simp::Cli::Commands::Environment::New < Simp::Cli::Commands::Command
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
    default_strategy = :skeleton
    # TODO: simp cli should read a config file that can override these defaults
    # these options (preferrable mimicking cmd-line args)
    options = {
      types: {
        puppet: {
          enabled: true,
          strategy: default_strategy, # :skeleton, :copy
          puppetfile: false,
          puppetfile_install: false,
          deploy: false,
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:config]['environmentpath'],
          skeleton_path: '/usr/share/simp/environments/simp',
          module_repos_path: '/usr/share/simp/git/puppet_modules',
          skeleton_modules_path: '/usr/share/simp/modules'
        },
        secondary: {
          enabled: true,
          strategy: default_strategy,   # :skeleton, :copy, :link
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:secondary_environment_path],
          skeleton_path: '/usr/share/simp/environments/secondary',
          rsync_skeleton_path: '/usr/share/simp/environments/rsync'
        },
        writable: {
          enabled: true,
          strategy: default_strategy,   # :fresh, :copy, :link
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:writable_environment_path]
        }
      }
    }
    options[:action] = :create

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
             simp env new development

             # Link staging's Secondary and Writable env dirs to production
             simp env new staging --link production

             # Create a separate copy of production (will diverge over time)
             simp env new newprod --copy production

             # Create new omni environment
             simp env new local_prod --puppetfile

        Options:

      HELP_MSG

      opts.on('--skeleton',
              '(default) Generate environments from skeleton templates.',
              'Implies --puppetfile') do
                options[:types][:puppet][:strategy]    = :skeleton
                options[:types][:secondary][:strategy] = :skeleton
                options[:types][:writable][:strategy]  = :fresh
                options[:types][:puppet][:puppetfile]  = true
              end

      opts.on('--copy ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Copy assets from ENVIRONMENT') do |src_env|
                options[:types][:puppet][:strategy]    = :copy
                options[:types][:secondary][:strategy] = :copy
                options[:types][:writable][:strategy]  = :copy
                options[:src_env] = src_env
              end

      opts.on('--link ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Symlink Secondary and Writeable environment directories',
              'to ENVIRONMENT.  If --puppet-env is set, the Puppet',
              'environment will --copy.') do |src_env|
                options[:types][:puppet][:strategy]    = :copy
                options[:types][:secondary][:strategy] = :copy
                options[:types][:writable][:strategy]  = :copy
                options[:src_env] = src_env
              end

      opts.on('--[no-]puppetfile',
              'Generate Puppetfiles in Puppet env directory',
              '  * `Puppetfile` will only be created if missing',
              '  * `Puppetfile.simp` will be generated from RPM/',
              '  * implies `--puppet-env`') do |v|
        options[:types][:puppet][:enabled] = true if (options[:types][:puppet][:puppetfile] = v)
      end

      opts.on('--[no-]puppetfile-install',
              'Automatically deploys Puppetfile in Puppet environment',
              'directory after creating it',
              '  * implies `--puppet-env`',
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

    require 'yaml'
    puts options.to_yaml, '', ''

    omni_controller = Simp::Cli::Environment::OmniEnvController.new(options, env)
    omni_controller.send(action)
  end
end
