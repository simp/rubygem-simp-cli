require 'facter'
require 'simp/cli'

module Simp::Cli::Puppetfile
  # Provides a skeleton Puppetfile that includes a local Puppetfile.simp
  # and can include local module refs
  class Skeleton
    SECTION_SEPARATOR    = '='*78
    SUBSECTION_SEPARATOR = '-'*78

    INTRO_SECTION = <<-INTRO.gsub(/ {6}/,'')
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

    LOCAL_MODULE_SECTION = <<-LOCAL.gsub(/ {6}/,'')
      # #{SECTION_SEPARATOR}
      # Your site's Puppet modules
      # #{SUBSECTION_SEPARATOR}
      # Add your own Puppet modules here
    LOCAL

    ROLES_PROFILES_SECTION = <<-ROLES_PROFILES.gsub(/ {6}/,'')
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
    def initialize(puppet_env = nil)
      @puppet_env = puppet_env
    end

    # @return [String] Skeleton Puppetfile that will load the contents of
    #   Puppetfile.simp when deployed. This Puppetfile will also include any
    #   local module references, when this object was constructed for a
    #   specific Puppet environment.
    def to_puppetfile
      puppetfile = header
      puppetfile += <<-PUPPETFILE.gsub(/ {8}/,'')
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
    #   for the environment
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
           if Dir.exist?('.git')
             if `#{git} remote -v`.strip.empty?
               local_mods << File.basename(module_dir)
             end
           else
             local_mods << File.basename(module_dir)
           end
        end
      end
      local_mods
    end

    # @returns a 'Generated' header when local modules are to be included
    #   in the generated Puppetfile
    def header
      return '' if  local_modules.empty?
      <<-HEADER.gsub(/ {8}/,'')
        # #{SECTION_SEPARATOR}
        # Puppetfile (Generated at #{Simp::Cli::Utils::timestamp} with local modules from
        # '#{@puppet_env}' Puppet environment)
        #
      HEADER
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

  end
end
