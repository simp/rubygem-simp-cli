class LocalSimpPuppetModule
  def initialize(metadata, simp_modules_git_repos_path)
    @simp_modules_git_repos_path = simp_modules_git_repos_path
    @data = metadata
    %w[name version].each do |field|
      unless @data.key? field
        fail("ERROR: could not read '#{field}' from module metadata ('#{mdj_file}')")
      end
    end
  end

  def tag_exists_for_version?
    tags = []
    Dir.chdir(local_git_repo_path) do |_dir|
      tags = %x(git tag -l).strip.split("\n").map(&:strip)
    end
    tags.include? @data['version']
  end

  def to_s
    tag_exists_for_version? # TODO: move into constructor
    <<-TO_S.gsub(%r{^ {6}}, '')
      mod '#{@data['name']}',
        :git => '#{local_git_repo_path}',
        :tag => '#{@data['version']}'

    TO_S
  end

  # module's local git repository
  # @param [String] name Full Puppet module name (e.g., `simp-simplib`)
  # @return [String] absolute pathname of local git repository
  # @fail [RuntimeError] if local git repository can't be found
  def local_git_repo_path
    @repo_path ||= File.join(@simp_modules_git_repos_path, "#{@data['name']}.git")
    unless File.directory?(@repo_path)
      # TODO: Should this be a warning + skip instead of a failure?
      fail("ERROR: Cannot find local git repository at '#{@repo_path}'")
    end
    @repo_path
  end
end
