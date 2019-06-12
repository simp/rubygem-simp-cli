# frozen_string_literal: true

require 'simp/cli/environment/dir_env'

require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a Puppet directory environment
  class PuppetDirEnv < DirEnv
    def initialize(name, base_environments_path, opts)
      super(:puppet, name, base_environments_path, opts)
      @skeleton_path = opts[:skeleton_path] || fail(ArgumentError, 'No :skeleton_path in opts')
      @puppetfile_simp_path = File.join(directory_path, 'Puppetfile.simp')
      @puppetfile_path = File.join(directory_path, 'Puppetfile')
    end

    # Create a new environment
    #
    #    - [x] A1.2 create directory from skeleton
    #    - [x] (option-driven) generate Puppetfile
    #    - [x] (option-driven) deploy modules (r10k puppetfile install)
    #
    # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def create
      fail_unless_createable

      case @opts[:strategy]
      when :skeleton
        create_environment_from_skeleton
      when :copy
        copy_environment_files(@opts[:src_env])
      when :link
        link_environment_dirs(@opts[:src_env])
      else
        fail("ERROR: Unknown Puppet environment create strategy: '#{@opts[:strategy]}'")
      end
    end

    # Fix consistency of Puppet directory environment
    #
    #     - [x] A3.2.1 applies Puppet user settings & groups to
    #       - [x] $codedir/environments/$ENVIRONMENT/
    #
    # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def fix
      # if environment is not available, fail with helpful message
      unless File.directory? @directory_path
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Puppet environment directory not found at '#{@directory_path}'"
        )
      end

      # apply Puppet group ownership to $codedir/environments/$ENVIRONMENT/
      #
      #   previous impl: https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L178-L180
      #
      #     (note: the previous impl affected the `simp` env skeleton, which was
      #      rsynced into $codedir/environments/simp)
      #
      apply_puppet_permissions(File.join(@directory_path), true, true)
    end

    # Update environment
    def update
      fail NotImplementedError
    end

    # Remove environment
    def remove
      fail NotImplementedError
    end

    # Validate consistency of environment
    def validate
      fail NotImplementedError
    end

    def create_environment_from_skeleton
      info("Creating #{@type} env '#{@directory_path}' from '#{@skeleton_path}'".cyan)

      # A1.2 copy from @skeleton_path into @directory_path
      #
      #   previous impl: https://github.com/simp/simp-adapter/blob/0.1.1/src/sbin/simp_rpm_helper#L351
      #
      puppet_group = puppet_info[:puppet_group]
      fail('Error: Could not determine puppet group') if puppet_group.to_s.empty?

      FileUtils.mkdir_p @directory_path, mode: 0755
      copy_skeleton_files(@skeleton_path, @directory_path, puppet_group)
      template_environment_conf

      # (option-driven) generate Puppetfile
      puppetfile_generate if @opts[:puppetfile_generate]

      # (option-driven) deploy modules (r10k puppetfile install)
      puppetfile_install if @opts[:puppetfile_install]
    end

    # Ensure all instances of %%SKELETON_ENVIRONMENT%% in `environment.conf`
    # are replaced with the environment name.
    def template_environment_conf
      env_conf_file = File.join(@directory_path, 'environment.conf')
      env_conf_template = "#{env_conf_file}.TEMPLATE"
      debug("Generating #{env_conf_file} from #{env_conf_template}")

      unless File.file?(env_conf_template)
        logger.warn "WARNING: No template found at '#{env_conf_template}'".yellow
        unless File.file?(env_conf)
          msg = "ERROR: No template and no conf file at #{env_conf_file}"
          fail(Simp::Cli::ProcessingError, msg)
        end
        return
      end

      if File.file?(env_conf_file)
        warn("WARNING: #{env_conf_file} already exists; replacing with template".red)
        FileUtils.rm_f env_conf_file
      end

      env_conf = File.read(env_conf_template)
      env_conf.gsub!('%%SKELETON_ENVIRONMENT%%', @name)
      FileUtils.mv env_conf_template, env_conf_file # Keeps perms, contexts, FACLs
      File.open(env_conf_file, 'w') { |f| f.puts(env_conf) }
    end

    def puppetfile_generate
      require 'simp/cli/puppetfile/local_simp_puppet_modules'
      puppetfile_modules = Simp::Cli::Puppetfile::LocalSimpPuppetModules.new(
        @opts[:skeleton_modules_path],
        @opts[:module_repos_path]
      )
      puppetfile_skeleton = Simp::Cli::Puppetfile::Skeleton.new

      logger.info "Generating Puppetfile from local git repos at '#{@puppetfile_path}'".cyan
      File.open(@puppetfile_path, 'w') do |f|
        f.puts puppetfile_modules.to_puppetfile
      end

      unless File.exists? @puppetfile_path
        say "Generating Puppetfile (to include Puppetfile.simp' at '#{@puppetfile_path}'".cyan
        File.open(@puppetfile_path, 'w') do |f|
          f.puts puppetfile_skeleton.to_puppetfile
        end
      end
    end

    def puppetfile_install
      r10k = 'r10k'
      r10k = '/usr/share/simp/bin/r10k' if File.executable?('/usr/share/simp/bin/r10k')
      r10k_cmd = "#{r10k} puppetfile install -v info"
      Dir.chdir(directory_path) do
        info("Running r10k from '#{directory_path}' to install Puppet modules".cyan)
        unless execute(r10k_cmd)
          fail(Simp::Cli::ProcessingError, "ERROR:  Failed to install Puppet modules using r10k'")
        end
      end
    end
  end
end
