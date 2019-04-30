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
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
        - [x] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [x] THEN FAIL WITH HELPFUL MESSAGE
        - [ ] else
          - [x] A1.2 create directory from skeleton
          - [ ] (option-driven) generate Puppetfile
          - [ ] (option-driven) deploy modules (r10k puppetfile install)

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
      fail('Error: Could not determine puppet group') if puppet_group.to_s.empty?

      copy_skeleton_files(@skeleton_path, @directory_path, puppet_group)

      # (option-driven) generate Puppetfile
      if @opts[:generate_puppetfile]
        require 'pry'; binding.pry
      end
      fail NotImplementedError
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

      cmd = "sg - #{group} #{rsync} -a --no-g '#{src_dir}'/ '#{dest_dir}'/ 2>&1"
      puts("Copying '#{src_dir}' files into '#{dest_dir}'")
      warn("Executing: #{cmd}")
      output = %x(#{cmd})
      warn("Output:\n#{output}")
      unless $CHILD_STATUS.success?
        fail(
          "ERROR: Copy of '#{src_dir}' into '#{dest_dir}' using '#{cmd}' " \
          "failed with the following error:\n" \
          "    #{output.gsub("\n", "\n    ")}"
        )
      end
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
