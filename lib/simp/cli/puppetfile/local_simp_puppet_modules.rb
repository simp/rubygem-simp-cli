require 'simp/cli/puppetfile/local_simp_puppet_module'
require 'simp/cli/utils'
require 'json'

# Puppetfile helper namespace
module Simp::Cli::Puppetfile
  # A collection of SIMP Puppet modules found on the local filesystem
  #   that can generate a working Puppetfile of its contents
  class LocalSimpPuppetModules
    def initialize(simp_modules_install_path, simp_modules_git_repos_path, ignore_bad_modules = true)
      @simp_modules_install_path   = simp_modules_install_path
      @simp_modules_git_repos_path = simp_modules_git_repos_path
      @ignore_bad_modules = ignore_bad_modules
    end

    # @return [Array<String>] list of metadata.json files
    def metadata_json_files
      unless File.directory?(@simp_modules_install_path)
        fail(Simp::Cli::ProcessingError, "ERROR: Missing modules directory at '#{@simp_modules_install_path}'")
      end
      mdj_files = Dir[File.join(@simp_modules_install_path, '*', 'metadata.json')]
      if mdj_files.empty?
        fail(Simp::Cli::ProcessingError, 'ERROR: No modules with metadata.json files found in ' \
          "'#{@simp_modules_install_path}'")
      end
      mdj_files
    end

    # Parses a module's metadata.json file and returns the data
    # @return [Hash] module metadata
    def metadata(mdj_file)
      fail(Simp::Cli::ProcessingError, "ERROR: '#{mdj_file}' does not exist") unless File.exist?(mdj_file)
      json = File.read(mdj_file)
      JSON.parse(json)
    end

    # @return [Array<LocalSimpPuppetModule>] valid SIMP modules found in
    #  the local SIMP Git repo path
    #
    # @raises Simp::Cli::ProcessingError upon detection of any invalid SIMP
    #   module, unless configured to ignore bad modules.  A module will be
    #   considered invalid if it does not have a local SIMP git repo, there
    #   are problems reading/parsing the module's metadata in its
    #   metadata.json file found in the module's RPM install path, or the
    #   local SIMP Git repo does not have a tag for the version in the
    #   RPM install path metadata.json file.
    def modules
      return @modules if @modules

      modules = []
      metadata_json_files.each do |mdj_file|
        begin
          mod = LocalSimpPuppetModule.new(metadata(mdj_file), @simp_modules_git_repos_path)
          modules << mod
        rescue Simp::Cli::Puppetfile::ModuleError => e
          if @ignore_bad_modules
            # TODO logger integration when this is called by other simp cli commands
            $stderr.puts "Ignoring module #{File.basename(File.dirname(mdj_file))}: #{e}"
          else
            raise Simp::Cli::ProcessingError.new(e.message)
          end
        end
      end
      @modules = modules
    end

    # @return [String] all modules' data as a Puppetfile
    def to_puppetfile
      hr = '-' * 78
      <<~TO_S
        # #{hr}
        # SIMP Puppetfile (Generated at #{Simp::Cli::Utils::timestamp})
        # #{hr}
        # This Puppetfile deploys SIMP Puppet modules from the local Git repositories at
        #   #{@simp_modules_git_repos_path}
        # referencing tagged Git commits that match the versions for each module
        # installed in
        #   #{@simp_modules_install_path}
        #
        # The Git repositories are automatically created and updated when SIMP module
        # RPMs are installed.
        # #{hr}

        #{modules.sort_by { |mod| mod.module_name }.join("\n")}
      TO_S
    end
  end
end
