require 'simp/cli/commands/command'
require 'simp/cli/commands/puppetfile'

# Cli command to print Puppetfile that deploys from local SIMP git repos
class Simp::Cli::Commands::Puppetfile::Generate < Simp::Cli::Commands::Command
  # @return [String] description of command
  def self.description
    'Print a Puppetfile that deploys from local SIMP git repos'
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
      opts.banner = '== simp puppetfile generate [options]'
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        This command prints a Puppetfile that deploys the current SIMP Puppet
        modules installed under #{@simp_modules_install_path} from the local SIMP git
        repositories, which are updated when new SIMP module RPMs are installed.

        Usage:

          simp puppetfile generate > Puppetfile.simp

          simp puppetfile generate --skeleton > Puppetfile

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

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    parse_command_line(args)
    if @puppetfile_type == :skeleton
      require 'simp/cli/puppetfile/skeleton'
      puts Simp::Cli::Puppetfile::Skeleton.to_puppetfile
    else
      require 'simp/cli/puppetfile/local_simp_puppet_modules'
      puts Simp::Cli::Puppetfile::LocalSimpPuppetModules.new(
        @simp_modules_install_path,
        @simp_modules_git_repos_path
      ).to_puppetfile
    end
  end
end
