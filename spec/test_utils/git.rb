module TestUtils
  module Git

    def self.clone_local_module_repo(repo_dir, clone_parent_dir)
      fail("#{repo_dir} must be a fully qualified path") if repo_dir[0] != '/'
      repo_url = "file://#{repo_dir}"
      Dir.chdir(clone_parent_dir) do
        run_command("git clone #{repo_url}")
      end
    end

    # creates a test bare repo, adds the specified file to it, and then
    # tags that initial commit with the specified tags
    #
    # NOTE:  Will create a checkout of that repo in the parent
    #        directory of repo_dir.
    #
    # +repo_dir+: fully qualified path of the repo to create
    # +file+:  fully qualified path of the file to add to the repo
    # +tags+: array of tags to add
    #
    # return URL to the repo
    # raise RuntimeError if repo_dir already exists, repo_dir and/or
    #   file is not a fully qualified path, or any git operation fails
    def self.create_bare_repo(repo_dir, file, tags = [])
      fail("#{repo_dir} already exists") if Dir.exist?(repo_dir)
      fail("#{repo_dir} must be a fully qualified path") if repo_dir[0] != '/'
      fail("#{file} must be a fully qualified path") if file[0] != '/'

      run_command("git init --bare #{repo_dir}")

      clone_dir = "#{repo_dir}_clone".gsub('.git','')
      run_command("git clone file://#{repo_dir} #{clone_dir}")

      Dir.chdir(clone_dir) do
        FileUtils.cp(file, '.')
        run_command("git add #{File.basename(file)}")
        run_command("git commit -m 'Added #{File.basename(file)}'")
        run_command('git push origin master')

        tags.each do |tag|
          run_command("git tag #{tag}")
          run_command("git push origin #{tag}")
        end
      end
    end

    def self.run_command(cmd)
      puts "Executing: #{cmd}"
      success = system(cmd)
      fail("'#{cmd}' failed") unless success
    end
  end
end
