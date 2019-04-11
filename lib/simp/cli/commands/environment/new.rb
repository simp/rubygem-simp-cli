require 'simp/cli/commands/command'
require 'simp/cli/environment/omni_env_controller'

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

    # TODO: simp cli should read a config file that can override
    # these options (preferrable mimicking cmd-line args)
    options = {
      action:   :create,
      strategy: :fresh,
      types: {
        puppet: {
          enabled:     true,
          strategy:   :skeleton, # :ignore, :skeleton, :copy
          puppetfile: false,
          deploy:     false,
          backend:    :directory,
        },
        secondary: {
          enabled:    true,
          strategy: :link,
          backend:  :directory,
        },
        writable: {
          enabled:    true,
          strategy: :link,
          backend:  :directory,
        }
      }
    }
    opt_parser = OptionParser.new do |opts|
      opts.banner = '== simp environment new [options]'
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        Usage:

          simp environment new ENVIRONMENT [OPTIONS]

        By default, this command will:

          * create a new environment (–-fresh)
          * raise an error if an environment directory already exists

        It can create a complete SIMP omni-environment with --puppet-env

        Examples:

             # Create a fresh new development environment
             simp env new development

             # Link staging's Secondary and Writable env dirs to production
             simp env new staging --link production

             # Create a separate copy of production (will diverge over time)
             simp env new newprod --copy production

             # Create new omni environment
             simp env new local_prod --puppetfile

        Options:

      HELP_MSG

      opts.on('--fresh',
              '(default) Generate environments from skeleton templates.',
              'Implies --puppetfile') do
                options[:strategy] = :fresh
                options[:puppetfile] = true
                # TODO: implement
                fail NotImplementedError, 'TODO: implement --fresh'
              end

      opts.on('--copy ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Copy assets from ENVIRONMENT') do |_src_env|
                # TODO: implement
                fail NotImplementedError, 'TODO: implement --copy'
              end

      opts.on('--link ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Symlink Secondary and Writeable environment directories',
              'to ENVIRONMENT.  If --puppet-env is set, the Puppet',
              'environment will --copy.') do |_src_env|
                # TODO: implement
                # TODO: implement --puppet-env => --copy logic
                fail NotImplementedError, 'TODO: implement --link'
              end
      opts.on('--[no-]puppetfile',
              'Generate Puppetfiles in Puppet env directory',
              '  * `Puppetfile` will only be created if missing',
              '* `Puppetfile.simp` will be generated from RPM/',
              '* implies `--puppet-env`') do |v|
                warn("========= v = '#{v}'")
                # TODO: implement
                # TODO: imply --puppet-env
                fail NotImplementedError, 'TODO: implement --[no-]puppetfile'
              end

      opts.on('--[no-]puppet-env',
              'Includes Puppet environment when `--puppet-env`',
              '(default: --no-puppet-env)'
             ) { |v| options[:types][:puppet][:enabled] = v }

      opts.on('--[no-]secondary-env',
              'Includes Secondary environment when `--secondary-env`',
              '(default: --secondary-env)'
             ) { |v| options[:types][:secondary][:enabled] = v }

      opts.on('--[no-]writable-env',
              'Includes writable environment when `--writable-env`',
              '(default: --writable-env)'
             ) { |v| options[:types][:writable][:enabled] = v }

      opts.separator ''
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        exit
      end
    end
    opt_parser.parse!(args)
    options
  end

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    options = parse_command_line(args)
    action  = options.delete(:action)

    if args.empty?
      warn('','-'*80,'WARNING: \'ENVIRONMENT\' is required.','-'*80,'')
      sleep 1
      help
    end

    env = args.shift

    unless env =~ Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME
      fail("ERROR: '#{env}' is not an acceptable environment name")
    end

    require 'yaml'
    puts options.to_yaml
    omni_controller = Simp::Cli::Environment::OmniEnvController.new( options, env )
    omni_controller.send(action)
  end
end
