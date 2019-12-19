require 'simp/cli/defaults'
require 'simp/cli/errors'
require 'simp/cli/utils'
require 'facter'
require 'json'

module Simp::Cli::Puppetfile
  # Provides a skeleton Puppetfile that includes a local Puppetfile.simp
  # and can include local module refs
  class Skeleton
    SECTION_SEPARATOR    = '='*78
    SUBSECTION_SEPARATOR = '-'*78

    INTRO_SECTION = <<~INTRO
      # #{SECTION_SEPARATOR}
      # SIMP Puppet modules
      # #{SUBSECTION_SEPARATOR}
      # The line below enables this Puppetfile to deploy all of SIMP's modules from a
      # neighboring `Puppetfile.simp` file.
      #
      # If you install SIMP modules locally from RPMs, you can generate a current
      # `Puppetfile.simp` at any time by running the command:
      #
      #     simp puppetfile generate > Puppetfile.simp
      #
      # You can regenerate a clean copy of this Puppetfile at any time by running:
      #
      #     simp puppetfile generate --skeleton > Puppetfile
      # OR
      #     simp puppetfile generate --skeleton --local-modules ENV > Puppetfile
      #
      # #{SUBSECTION_SEPARATOR}
    INTRO

    LOCAL_MODULE_SECTION = <<~LOCAL
      # #{SECTION_SEPARATOR}
      # Your site's Puppet modules
      # #{SUBSECTION_SEPARATOR}
      # Add your own Puppet modules here
    LOCAL

    ROLES_PROFILES_SECTION = <<~ROLES_PROFILES
      # #{SECTION_SEPARATOR}
      # A note about Roles and Profiles
      # #{SUBSECTION_SEPARATOR}
      # Site administrators are strongly encouraged to use Roles and Profiles to
      # keep their infrastructure management organized.
      #
      # It is recommended to add Roles and Profiles under a `site/` modules directory
      # at the top level of the environment directory (or control repository).
      #
      # Further reading:
      #
      #   * https://github.com/puppetlabs/best-practices/blob/master/control-repo-contents.md
      #   * https://puppet.com/docs/pe/latest/the_roles_and_profiles_method.html
      #   * https://github.com/puppetlabs/best-practices/blob/master/puppet-code-abstraction-roles.md
      #   * https://github.com/puppetlabs/best-practices/blob/master/puppet-code-abstraction-profiles.md
      #
      # If you prefer instead to manage your site using a separate site module, uncomment the
      # following `mod` entry and replace the URL with your site module's repository:
      #
      # mod 'simp-site',
      #  :git => 'https://github.com/simp/pupmod-simp-site'
    ROLES_PROFILES

    # @param puppet_env Optional name of a Puppet environment in which to
    #   find local Puppet modules to be included in the generated Puppetfile
    # @param simp_modules_git_repos_path Fully qualified path to the local,
    #   SIMP-managed Git repositories for modules
    def initialize(puppet_env = nil, simp_modules_git_repos_path = Simp::Cli::SIMP_MODULES_GIT_REPOS_PATH)
      @puppet_env = puppet_env
      @simp_modules_git_repos_path = simp_modules_git_repos_path
    end

    # @return [String] Skeleton Puppetfile that will load the contents of
    #   Puppetfile.simp when deployed. This Puppetfile will also include any
    #   local module references, when this object was constructed for a
    #   specific Puppet environment.
    def to_puppetfile
      puppetfile = header
      puppetfile += <<~PUPPETFILE
        #{INTRO_SECTION}
        instance_eval(File.read(File.join(__dir__,"Puppetfile.simp")))


        #{LOCAL_MODULE_SECTION}
        #{local_modules.sort.map { |mod_name| "mod '#{mod_name}', :local => true" }.join("\n")}


        #{ROLES_PROFILES_SECTION}

      PUPPETFILE
      puppetfile
    end

    private

    # @returns List of local modules found in the standard module path
    #   for the environment for which a local SIMP-owned Git repository
    #   does not exist
    #
    # NOTE:
    # - A local module is a module that does not have a .git subdirectory
    #   or, if it does have a .git subdirectory, has no remotes defined.
    # - This utility is targeted at handling modules in the standard
    #   module location `environmentpath`/<environment name>/modules,
    #   only. No other directories in the `modulepath` will be examined.
    #   The standard location is used by r10k deploy/install by default.
    # - Even though r10K provides support for SVN, we are going to
    #   conservatively consider modules that may be under SVN control to
    #   be local modules, as well.
    #
    def find_local_modules(puppet_env)
      git = Facter::Core::Execution.which('git')
      fail(Simp::Cli::ProcessingError, "Error: Could not find 'git' command!") unless git

      # Find module sub-directories
      env_path = Simp::Cli::Utils::puppet_info(puppet_env)[:environment_path]
      mdj_files = Dir.glob(File.join(env_path, puppet_env, 'modules', '*', 'metadata.json'))
      module_dirs = mdj_files.map { |mdj_file| File.dirname(mdj_file) }

      # Find local modules
      local_mods = []
      module_dirs.each do |module_dir|
        Dir.chdir(module_dir) do
           metadata = load_metadata(module_dir)
           next if metadata.nil?

           if Dir.exist?('.git')
             if `#{git} remote -v`.strip.empty?
               local_mods << [ File.basename(module_dir), metadata['name'] ]
             end
           else
             local_mods << [ File.basename(module_dir), metadata['name'] ]
           end
        end
      end

      # Remove any 'local' modules for which a local Git repo exists
      local_mods.delete_if do |mod_name, org_plus_name|
        Dir.exist?(File.join(@simp_modules_git_repos_path, "#{org_plus_name}.git"))
      end

      # Remove any 'local' module which is obsoleted by a currently-installed
      # module RPM for which there is a local Git repo.
      # NOTE:  There may be modules that were obsoleted by the 'simp' or
      #        'simp-extras' RPMs (e.g., simp-site, simp-simpcat), but it
      #         would be too aggressive to remove those...
      local_mods.delete_if do |mod_name, org_plus_name|
        local_module_obsolete?(org_plus_name)
      end

      local_mods.map { |name_pair| name_pair.first }
    end

    # @returns a 'Generated' header when local modules are to be included
    #   in the generated Puppetfile
    def header
      return '' if  local_modules.empty?
      <<~HEADER
        # #{SECTION_SEPARATOR}
        # Puppetfile (Generated at #{Simp::Cli::Utils::timestamp} with local modules from
        # '#{@puppet_env}' Puppet environment)
        #
      HEADER
    end

    # @returns Hash representation of the metadata.json file in the specified
    #   module_dir or nil if the metadata.json file is invalid
    #
    # Logs the metadata.json failure to stderr
    def load_metadata(module_dir)
      mdj_file = File.join(module_dir, 'metadata.json')
      unless File.exist?(mdj_file)
        $stderr.puts "Ignoring local module #{module_dir}: metadata.json missing"
        return nil
      end

      metadata = nil
      begin
        metadata = JSON.parse(File.read(mdj_file))
        unless metadata['name']
          $stderr.puts "Ignoring local module #{module_dir}: 'name' missing from metadata.json"
          metadata = nil
        end
      rescue JSON::JSONError => e
        $stderr.puts "Ignoring local module #{module_dir}: #{e}"
      end
      metadata
    end

    # @returns Array of local modules for the specified Puppet
    #   environment or [], when no Puppet environment is specified
    # @see find_local_modules
    def local_modules
      return @local_modules if @local_modules

      if @puppet_env.nil?
        @local_modules = []
      else
        @local_modules = find_local_modules(@puppet_env)
      end
      @local_modules
    end

    # Returns true if the specified module is obsoleted by a currently-installed
    # module RPM for which there is a local Git repo
    #
    # @param org_plus_name Name of the module as specified in the module's
    #   metadata.json file (i.e., <org>-<name>).
    def local_module_obsolete?(org_plus_name)
      module_name = org_plus_name.split('-').last
      possible_matches = Dir.glob(File.join(@simp_modules_git_repos_path, "*-#{module_name}.git"))
      return false if possible_matches.empty?

      obsolete = false
      possible_matches.map! { |repo_name| "pupmod-#{File.basename(repo_name, '.git')}" }
      possible_matches.each do |pkg_name|
        result = %x{rpm -q #{pkg_name} --obsoletes 2>&1}
        if result.match(/^pupmod-#{org_plus_name}(\s)+/)
          obsolete = true
          break
        end
      end
      obsolete
    end

  end
end
