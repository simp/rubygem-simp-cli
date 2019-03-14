require 'simp/cli'
module Simp::Cli::Puppetfile
  class LocalSimpPuppetModule
    def initialize(metadata, simp_modules_git_repos_path)
      @simp_modules_git_repos_path = simp_modules_git_repos_path
      @data = metadata

      %w[name version].each do |field|
        unless @data.is_a?(Hash) && @data.key?(field)
          fail("ERROR: Could not read '#{field}' from module metadata")
        end
      end
    end

    # @return [String] module data as a line in a Puppetfile
    def to_s
      <<-TO_S.gsub(%r{^ {8}}, '')
        mod '#{@data['name']}',
          :git => '#{local_git_repo_path}',
          :tag => '#{@data['version']}'

      TO_S
    end

    # Return `true` if there is a tag matching the module's version
    # @return [true] if there is a tag
    # @return [false] if there is no tags match
    def tag_exists_for_version?
      tags = []
      Dir.chdir(local_git_repo_path) do |_dir|
        tags = %x(git tag -l).strip.split("\n").map(&:strip)
      end
      tags.include?(@data['version']) || fail(
        "ERROR: Tag '#{@data['version']}' not found in local repo " \
          "'#{local_git_repo_path}'"
      )
      true
    end

    # module's local git repository
    # @param [String] name Full Puppet module name (e.g., `simp-simplib`)
    # @return [String] absolute pathname of local git repository
    # @fail [RuntimeError] if local git repository can't be found
    def local_git_repo_path
      @repo_path ||= File.join(@simp_modules_git_repos_path, "#{@data['name']}.git")
      unless File.directory?(@repo_path)
        # TODO: Should this be a warning + skip instead of a failure?
        fail("ERROR: Missing local git repository at '#{@repo_path}'")
      end
      @repo_path
    end
  end
end
