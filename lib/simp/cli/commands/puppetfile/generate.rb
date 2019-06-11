require 'simp/cli/commands/command'
require 'simp/cli/puppetfile/errors'
require 'simp/cli/puppetfile/local_simp_puppet_modules'
require 'simp/cli/puppetfile/skeleton'
require 'simp/cli/utils'

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
      @puppet_env = nil
      opts.banner = '== simp puppetfile generate [options]'
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        This command prints one of two types of Puppetfiles:

        * A Puppetfile that deploys the current set of SIMP Puppet modules installed in
            #{@simp_modules_install_path}
          from the corresponding local Git repositories in
            #{@simp_modules_git_repos_path}.

        * A skeleton, parent Puppetfile that includes Puppetfile.simp, the assumed name
          of the Puppetfile containing only SIMP modules.
          - This parent Puppetfile will deploy the modules in Puppetfile.simp, along
            with any other modules specified in it.
          - You can optionally have local modules in a specified environment
            automatically added to this parent Puppetfile.  Local modules are modules
            whose directories are not under Git source control.

        Usage:

          simp puppetfile generate -h

          # Generate a SIMP-only Puppetfile
          simp puppetfile generate  > Puppetfile.simp

          # Generate an empty Puppetfile that includes Puppetfile.simp
          simp puppetfile generate --skeleton > Puppetfile

          # Generate a Puppetfile that includes Puppetfile.simp and marks any unmanaged
          # directories that exist under Puppet environment ENV's modules/ directory as
          # `:local => true`
          simp puppetfile generate --skeleton --local-modules ENV > Puppetfile

        Options:

      HELP_MSG

      opts.on('-s', '--[no-]skeleton',
              'Generate an empty Puppetfile that includes',
              'Puppetfile.simp.',
             ) do |skel|
                 @puppetfile_type = skel ? :skeleton : :simp
              end

      opts.on('-l', '--local-modules ENV',
              Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME,
              'When generating a Puppetfile skeleton, scan',
              'through the modules/ directory of Puppet',
              'environment ENV, and mark any unmanaged',
              'directories with `:local => true`.',
              'This instructs r10k not to remove these',
              'directories during `puppetfile install` and',
              '`deploy environment`.',
              '(This option only affects --skeleton)') do |puppet_env|
                @puppet_env = puppet_env if puppet_env
              end

      opts.on('--modulepath PATH', Simp::Cli::Utils::REGEXP_UNIXPATH,
              'Specify the SIMP module installation path',
              "(default: #{Simp::Cli::SIMP_MODULES_INSTALL_PATH})") do |path|
                @simp_modules_install_path = path
              end

      opts.on('--repopath PATH', Simp::Cli::Utils::REGEXP_UNIXPATH,
              'Specify the SIMP module git repos path',
              "(default: #{Simp::Cli::SIMP_MODULES_GIT_REPOS_PATH})") do |path|
                @simp_modules_git_repos_path = path
              end

      opts.separator ''
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        @help_requested = true
      end
    end
    opt_parser.order!(args)
  end

  # Run command logic
  # @param args [Array<String>] ARGV-style args array
  def run(args)
    parse_command_line(args)
    return if @help_requested

    if @puppetfile_type == :skeleton
      puts Simp::Cli::Puppetfile::Skeleton.new(@puppet_env).to_puppetfile
    else
      puts Simp::Cli::Puppetfile::LocalSimpPuppetModules.new(
        @simp_modules_install_path,
        @simp_modules_git_repos_path
      ).to_puppetfile
    end

  rescue Simp::Cli::Puppetfile::ModuleError => e
    # backtrace is not useful here, so only report the error message
    raise Simp::Cli::ProcessingError.new(e.message)
  end
end
