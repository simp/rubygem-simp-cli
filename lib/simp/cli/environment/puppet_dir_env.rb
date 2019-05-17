# frozen_string_literal: true

require 'simp/cli/environment/dir_env'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a Puppet directory environment
  class PuppetDirEnv < DirEnv
    def initialize(name, base_environments_path, opts)
      super(name, base_environments_path, opts)
      @skeleton_path = opts[:skeleton_path] || fail(ArgumentError, 'No :skeleton_path in opts')
      @puppetfile_path = File.join(directory_path,'Puppetfile')
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
        - [x] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [x] THEN FAIL WITH HELPFUL MESSAGE
        - [x] else
          - [x] A1.2 create directory from skeleton
          - [x] (option-driven) generate Puppetfile
          - [x] (option-driven) deploy modules (r10k puppetfile install)

      TODO

      # Safety feature: Don't clobber a Puppet environment directory that already has content
      unless Dir.glob(File.join(@directory_path, '*')).empty?
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: A Puppet environment directory with content already exists at '#{@directory_path}'"
        )
      end

      # A1.2 copy from @skeleton_path into @directory_path
      #
      #   previous impl: https://github.com/simp/simp-adapter/blob/0.1.1/src/sbin/simp_rpm_helper#L351
      #
      puppet_group = puppet_info[:puppet_group]
      fail( 'Error: Could not determine puppet group' ) if puppet_group.to_s.empty?
      copy_skeleton_files(@skeleton_path, @directory_path, puppet_group)

      # (option-driven) generate Puppetfile
      puppetfile_generate if @opts[:puppetfile_generate]

      # (option-driven) deploy modules (r10k puppetfile install)
      puppetfile_install if @opts[:puppetfile_install]
    end


    def puppetfile_generate
      require 'simp/cli/puppetfile/local_simp_puppet_modules'
      puppetfile_modules = Simp::Cli::Puppetfile::LocalSimpPuppetModules.new(
        @opts[:skeleton_modules_path],
        @opts[:module_repos_path]
      )

      puts "Generating Puppetfile from local git repos at '#{@puppetfile_path}'"
      File.open(@puppetfile_path,'w') do |f|
        f.puts puppetfile_modules.to_puppetfile
      end
    end

    def puppetfile_install
        r10k_cmd = 'r10k puppetfile install -vvv'
        cmd = "cd '#{directory_path}' && #{r10k_cmd}"
        puts "Running r10k from '#{directory_path}' to install Puppet modules:"
        puts "#{'-'*80}\n\n\t#{r10k_cmd}\n\n#{'-'*80}\n"
        require 'open3'

        exit_status = ':|'
        Open3.popen2(cmd) do |i,o,t|
          i.close
          p o.read #=> "*"
          exit_status = t.value # Process::Status object returned.
        end
        fail("Command failed: '#{r10k_cmd}'") unless exit_status.success?
    end

    # Fix consistency of Puppet directory environment
    def fix
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [x] if environment is not available (#{@directory_path} not found)
             - [x] THEN FAIL WITH HELPFUL MESSAGE
          - [x] A3.2.1 applies Puppet user settings & groups to
            - [x] $codedir/environments/$ENVIRONMENT/

      TODO

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
      apply_puppet_permissions(File.join(@directory_path), false, true)
    end

    def copy_skeleton_files(src_dir, dest_dir, group)
      rsync = Facter::Core::Execution.which('rsync')
      fail("Error: Could not find 'rsync' command!") unless rsync

      puts("Copying '#{src_dir}' files into '#{dest_dir}'")
      if ENV.fetch('USER') == 'root'
        cmd = "sg - #{group} #{rsync} -a --no-g '#{src_dir}'/ '#{dest_dir}'/ 2>&1"
      else
        cmd = "#{rsync} -a  '#{src_dir}'/ '#{dest_dir}'/ 2>&1"
      end
      warn("Executing: #{cmd}")
      output = %x(#{cmd})
      warn("Output:\n#{output}")
      return if $CHILD_STATUS.success?

      fail(
        "ERROR: Copy of '#{src_dir}' into '#{dest_dir}' using '#{cmd}' " \
        "failed with the following error:\n" \
        "    #{output.gsub("\n", "\n    ")}"
      )
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
  end
end
