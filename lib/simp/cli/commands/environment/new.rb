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
    opt_parser = OptionParser.new do |opts|
      @simp_modules_install_path   ||= Simp::Cli::SIMP_MODULES_INSTALL_PATH
      @simp_modules_git_repos_path ||= Simp::Cli::SIMP_MODULES_GIT_REPOS_PATH
      @puppetfile_type ||= :simp
      opts.banner = '== simp environment new [options]'
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        This command prints a Puppetfile that deploys the current SIMP Puppet
        modules installed under #{@simp_modules_install_path} from the local SIMP git
        repositories, which are updated when new SIMP module RPMs are installed.

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

             # Create new omni environment, 
             simp env new local_prod --puppetfile


        Options:

      HELP_MSG

      opts.on('-s', '--skeleton',
              'Generate an empty Puppetfile that includes',
              'Puppetfile.simp') { @puppetfile_type = :skeleton }

      opts.on('--modulepath PATH', Simp::Cli::Utils::REGEXP_UNIXPATH,
              'Specify SIMP module installation path',
              "(default: #{Simp::Cli::SIMP_MODULES_INSTALL_PATH})") do |path|
                @simp_modules_install_path = path
              end

      opts.on('--repopath PATH', Simp::Cli::Utils::REGEXP_UNIXPATH,
              'Specify SIMP module git repos path',
              "(default: #{Simp::Cli::SIMP_MODULES_GIT_REPOS_PATH})") do |path|
                @simp_modules_git_repos_path = path
              end

      opts.separator ''
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        exit
      end
    end
    opt_parser.order!(args)
  end

end
