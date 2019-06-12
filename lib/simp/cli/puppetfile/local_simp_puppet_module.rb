require 'simp/cli'

module Simp::Cli::Puppetfile
  # Puppet module data for SIMP modules installed via RPM and
  # imported in local Git repos
  #
  # @param metadata Module's metadata read in from its metadata.json file
  #   in the RPM installation directory
  # @param simp_modules_git_repos_path Path to the local SIMP module Git repos
  #
  # @raise [Simp::Cli::Puppetfile::ModuleError] if the module's local Git repo
  #   is missing or the module's local Git repo does not contain a tag matching
  #   the version in the specified metadata.json
  class LocalSimpPuppetModule
    def initialize(metadata, simp_modules_git_repos_path)
      @data = metadata
      @simp_modules_git_repos_path = simp_modules_git_repos_path

      %w[name version].each do |field|
        unless @data.is_a?(Hash) && @data.key?(field)
          msg = "ERROR: Could not read '#{field}' from module metadata"
          fail(Simp::Cli::Puppetfile::ModuleError, msg)
        end
      end

      verify_tag_exists_for_version
    end

    # @return module full name as it exists in the module's metadata
    def module_name
      @data['name']
    end

    # @return [String] module data as a line in a Puppetfile
    def to_s
      <<-TO_S.gsub(%r{^ {8}}, '')
        mod '#{@data['name']}',
          :git => 'file://#{local_git_repo_path}',
          :tag => '#{@data['version']}'
      TO_S
    end

    private

    # Verifies there is a tag matching the module's version
    # @raise [Simp::Cli::Puppetfile::ModuleError] if no matching tag is found
    def verify_tag_exists_for_version
      tags = []
      Dir.chdir(local_git_repo_path) do
        tags = %x(git tag -l).strip.split("\n").map(&:strip)
      end
      unless tags.include?(@data['version'])
        msg = "ERROR: Tag '#{@data['version']}' not found in local repo " \
          "'#{local_git_repo_path}'"
        fail(Simp::Cli::Puppetfile::ModuleError, msg)
      end
    end

    # module's local git repository
    # @return [String] absolute pathname of local git repository
    # @raise [Simp::Cli::Puppetfile::ModuleError] if local git repository
    #   can't be found
    def local_git_repo_path
      return @repo_path unless @repo_path.nil?

      @repo_path = File.join(@simp_modules_git_repos_path, "#{@data['name']}.git")
      unless File.directory?(@repo_path)
        msg = "ERROR: Missing local git repository at '#{@repo_path}'"
        fail(Simp::Cli::Puppetfile::ModuleError, msg)
      end
      @repo_path
    end
  end
end
