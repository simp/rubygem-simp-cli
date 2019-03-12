require 'simp/cli/commands/command'
require 'simp/cli/commands/puppetfile'
require 'json'

class PuppetModuleRpmRepoScanner
  def initialize
    @simp_rpm_module_path = '/usr/share/simp/modules'
    @simp_git_repo_path   = '/usr/share/simp/git/puppet_modules'
  end

  def pupmod_rpm_list
    rpm_modules = `rpm -qa`.strip.split("\n").grep(%r{^pupmod-})
    fail('ERROR: No "pupmod-" RPMs found on system.') if rpm_modules.empty?
    rpm_modules
  end

  def metadata(mdj_file)
    fail("ERROR: No metadata.json at '#{mdj_file}'") unless File.exists?(mdj_file)
    json = File.read(mdj_file)
    JSON.parse(json)
  end

  # Search RPM manifest for the module's top-level metadata.json
  def metadata_json_path_from_rpm(rpm)
    mdj_files = `rpm -ql #{rpm}`.strip.split("\n").grep(
      %r{^#{@simp_rpm_module_path}/[^/]+/metadata\.json}
    )
    unless mdj_files.size == 1
      fail("ERROR: Expected one top-level metadata.json file for '#{rpm}':" \
        "\n\n#{mdj_files.map{|x| "  - #{x}" }}\n\n" )
    end
    mdj_files.first
  end

  def local_git_repo_path(name)
    repo_path = File.join(@simp_git_repo_path,"#{name}.git")
    unless File.directory?(repo_path)
      fail("ERROR: Cannot find local git repository at '#{repo_path}'")
    end
    repo_path
  end

  def run
    result = {}
    pupmod_rpm_list.each do |rpm|
      mdj_file = metadata_json_path_from_rpm(rpm)
      data = metadata(mdj_file)
      name = data['name'] || fail("ERROR: could not read name from module metadata ('#{mdj_file}')")
      git_repo = local_git_repo_path(name)
      require 'pry'; binding.pry
    end
    result
  end

  def scan_module
    # For each module:
    # get variables
    forge_org   = nil
    module_name = nil
    # check: do RPM files exist? || fail()
    module_version = nil # metadata.json
    # check: local git repo exists || fail()
    puts forge_org, module_name, module_version
  end
end

class Simp::Cli::Commands::Puppetfile::Generate < Simp::Cli::Commands::Command

  def self.description
    'Generate a Puppetfile from SIMP RPM-managed local git repos'
  end

  # Run the command's `--help` action
  def help
    parse_command_line( [ '--help' ] )
  end

  # Parse command-line options for the command
  # @param args [Array<String>] ARGV-style args array
  def parse_command_line(args)
    opt_parser = OptionParser.new do |opts|
      opts.banner = "simp puppetfile generate [options]"
      opts.separator <<-HELP_MSG.gsub(%r{^ {8}}, '')

        #{self.class.description}

        Options:

      HELP_MSG

      opts.on('-k', '--kill_agent', 'Ignore the status of agent_catalog_run_lockfile, and',
              'force kill active puppet agents at the beginning of',
              'bootstrap') do |_k|
        @kill_agent = true
      end

      opts.separator ""
      opts.on_tail('-h', '--help', 'Print this message') do
        puts opts
        exit
      end
    end
    opt_parser.order!(args)
  end

  # Run command
  def run(args)
    parse_command_line(args)
    pmrr_scanner = PuppetModuleRpmRepoScanner.new
    pmrr_scanner.run
  end
end

