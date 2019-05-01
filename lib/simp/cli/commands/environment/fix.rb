# frozen_string_literal: true

require 'simp/cli/commands/command'
require 'simp/cli/environment/omni_env_controller'

# Cli command to fix an Extra/Omni environment
#
# TODO: As more `simp environment` sub-commands are added, a lot of this code
#      could probably be abstracted into a common class or mixin
class Simp::Cli::Commands::Environment::Fix < Simp::Cli::Commands::Command
  # @return [String] description of command
  def self.description
    'Re-apply FACLs, SELinux contexts, and permissions to omni-environment files'
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
    # TODO: centralize these defs across `simp environment` sub-commands
    options = {
      types: {
        puppet: {
          enabled: true,
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:config]['environmentpath']
          skeleton_path: '/usr/share/simp/environments/simp',
          module_repos_path: '/usr/share/simp/git/puppet_modules',
          skeleton_modules_path: '/usr/share/simp/modules'
        },
        secondary: {
          enabled: true,
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:secondary_environment_path],
          skeleton_path: '/usr/share/simp/environments/secondary',
          rsync_skeleton_path: '/usr/share/simp/environments/rsync'
        },
        writable: {
          enabled: true,
          backend: :directory,
          environmentpath: Simp::Cli::Utils.puppet_info[:writable_environment_path]
        }
      }
    }
    options[:action] = :fix

    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp environment new [options]'
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        Usage:

            simp environment fix ENVIRONMENT [OPTIONS]

        Actions:

          * Ensure SELinux contexts under all environment directories (`fixfiles restore`)
          * Restore FACLs under ${SECONDARY_ENVDIR} ${PUPPET_ENVDIR} ${WRITABLE_ENVDIR}`
          * If ${SECONDARY_ENVDIR}/FakeCA/cacertkey doesn't exist, fill it will random gibberish

        Options:

      HELP_MSG

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
