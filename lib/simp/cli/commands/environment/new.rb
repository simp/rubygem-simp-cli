require 'simp/cli/commands/command'
class Simp::Cli::Commands::Environment::New < Simp::Cli::Commands::Command
  # @return [String] description of command
  def self.description
    'Create a new SIMP "Extra" (default) or "omni" environment'
  end

  # Run the command's `--help` action
  def help
    parse_command_line(['--help'])
  end

  # Parse command-line options for this simp command
  # @param args [Array<String>] ARGV-style args array
  def parse_command_line(args)
    options = {
      action: :fresh,
      types: {
        puppet: {
          action: false, # false, :copy, :link
          puppetfile: false
        },
        secondary: {
          action:  :link,
          backend: :dir
        },
        writable: {
          action:  :link,
          backend: :dir
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
                options[:action] = :fresh
                options[:puppetfile] = true
                # TODO: implement
                warn('TODO: implement --fresh')
              end

      opts.on('--copy ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Copy assets from ENVIRONMENT') do |_src_env|
                # TODO: implement
                warn('TODO: implement --copy')
              end

      opts.on('--link ENVIRONMENT', Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'Symlink Secondary and Writeable environment directories',
              'from ENVIRONMENT') do |_src_env|
                # TODO: implement
                warn('TODO: implement --link')
              end
      opts.on('--[no-]puppetfile',
              'Generate Puppetfiles in Puppet env directory',
              '  * `Puppetfile` will only be created if missing',
              '* `Puppetfile.simp` will be generated from RPM/',
              '* implies `--puppet-env`') do |v|
                warn("========= v = '#{v}'")
                # TODO: implement
                # TODO: imply --puppet-env
                warn('TODO: implement --[no-]puppetfile')
              end

      opts.separator ''
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        exit
      end
    end
    opt_parser.parse!(args)
  end

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    parse_command_line(args)
    if args.empty?
      warn("WARNING: 'ENVIRONMENT' is required.\n\n")
      help
    end

    env = args.shift
    unless env =~ Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME
      fail("ERROR: '#{env}' is not an acceptable environment name")
    end

    # TODO: logic
    warn("TODO: run(): **** simp environment new '#{env}' (#{args.map { |x| "'#{x}'" }.join(',')}) *** ")
  end
end
