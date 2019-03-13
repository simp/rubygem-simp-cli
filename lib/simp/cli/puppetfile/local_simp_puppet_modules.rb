require 'simp/cli/puppetfile/local_simp_puppet_module'
require 'json'

module Simp::Cli::Puppetfile
  class LocalSimpPuppetModules
    def initialize(simp_modules_install_path, simp_modules_git_repos_path)
      @simp_modules_install_path   = simp_modules_install_path
      @simp_modules_git_repos_path = simp_modules_git_repos_path
    end

    # @return [Array<String>] list of metadata.json files
    def metadata_json_files
      unless File.directory?(@simp_modules_install_path)
        fail("ERROR: Missing modules directory at '#{@simp_modules_install_path}'")
      end
      mdj_files = Dir[File.join(@simp_modules_install_path, '*', 'metadata.json')]
      if mdj_files.empty?
        fail( "ERROR: No modules with metadata.json files found in " \
          "'#{@simp_modules_install_path}'" )
      end
      mdj_files
    end

    # Parses a module's metadata.json file
    # @return [Hash] module metadata
    def metadata(mdj_file)
      fail("ERROR: No metadata.json file at '#{mdj_file}'") unless File.exist?(mdj_file)
      json = File.read(mdj_file)
      JSON.parse(json)
    end

    def modules
      return @modules if @modules
      modules = []
      metadata_json_files.each do |mdj_file|
        mod = LocalSimpPuppetModule.new(metadata(mdj_file), @simp_modules_git_repos_path)
        modules << mod
      end
      @modules ||= modules
    end

    def timestamp
      Time.now.utc.strftime('%Y-%m-%d %H:%M:%SZ')
    end

    def to_puppetfile
      hr = '-' * 78
      <<-TO_S.gsub(%r{^ {8}}, '')
        # #{hr}
        # SIMP Puppetfile (Generated at #{timestamp})
        # #{hr}
        # This Puppetfile deploys SIMP Puppet modules from the local git repositories
        # installed at #{@simp_modules_git_repos_path}, referencing tagged git commits
        # that match the versions for each module installed in #{@simp_modules_install_path}.
        # #{hr}

        #{modules.join("\n")}
      TO_S
    end
  end
end
