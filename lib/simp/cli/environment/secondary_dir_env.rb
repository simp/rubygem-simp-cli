# frozen_string_literal: true

require 'simp/cli/environment/dir_env'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a "Secondary" SIMP directory environment
  # @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/760840207/Environments
  class SecondaryDirEnv < DirEnv
    def initialize(name, base_environments_path, opts)
      super(name, base_environments_path, opts)
      @skeleton_path = opts[:skeleton_path] || fail(ArgumentError, 'No :skeleton_path in opts')
      (@rsync_skeleton_path = opts[:rsync_skeleton_path]) || fail(ArgumentError, 'No :rsync_skeleton_path in opts')
      @rsync_path = File.join(@directory_path, 'rsync')
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
        - [x] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [x] THEN FAIL WITH HELPFUL MESSAGE
        - [ ] else
          - [ ] A1.2 create directory from skeleton
            - [ ] C1.2 copy rsync files to ${ENVIRONMENT}/rsync/
            - [ ] C2.1 copy rsync files to ${ENVIRONMENT}/rsync/
               - [ ] this should include any logic needed to ensure a basic DNS environment
            - [ ] A5.2 ensure a `cacertkey` exists for FakeCA
               - Should this also be in fix()?

      TODO

      if File.exist? @directory_path
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Secondary environment directory already exists at '#{@directory_path}'\n"
        )
      end

      puts 'create!'
    end

    # Fix consistency of environment
    #   @see https://simp-project.atlassian.net/wiki/spaces/SD/pages/edit/757497857#simp_cli_environment_changes
    def fix
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [x] if environment is not available (#{@directory_path} not found)
             - [x] THEN FAIL WITH HELPFUL MESSAGE
          - [x] A2.2 apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
          - [x] A2.3 apply the correct SELinux contexts on demand
          - [x] A3.2.2 apply Puppet group ownership to $ENVIRONMENT/site_files/
          - [x] C3.2 ensure correct FACLS

      TODO

      # if environment is not available, fail with helpful message
      unless File.directory? @directory_path
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: secondary directory not found at '#{@directory_path}'"
        )
      end

      # apply SELinux fixfiles restore to the ${ENVIRONMENT}/ + subdirectories
      #
      #   previous impl: https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L185-L190
      #
      selinux_fix_file_contexts([@directory_path])

      # apply Puppet group ownership to $ENVIRONMENT/site_files/
      #
      #   previous impl: https://github.com/simp/simp-environment-skeleton/blob/6.3.0/build/simp-environment.spec#L181
      #
      apply_puppet_permissions(File.join(@directory_path, 'site_files'), false, true)

      # ensure correct FACLS on rsync/ files
      #
      #   previous impl: https://github.com/simp/simp-rsync-skeleton/blob/6.2.1/build/simp-rsync.spec#L98-L99
      #
      apply_facls(@rsync_path, File.join(@rsync_path, '.rsync.facl'))
    end

    # Apply FACL permissions to a path using a file for `setfacl --restore`
    # @param [String] path       absolute path set FACLs
    # @param [String] facl_file  absolutre path to rsync facl rules
    def apply_facls(path, facl_file)
      unless File.exist? @directory_path
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: Path does not exist to set FACLS: '#{path}'"
        )
      end
      fail(Simp::Cli::ProcessingError, "ERROR: No FACL file at '#{facl_file}'") unless File.exist?(facl_file)

      say "Applying FACL rules to #{path}".cyan
      system("cd #{path} && setfacl --restore=#{facl_file} 2>/dev/null")
      return if $CHILD_STATUS.success?

      fail(
        Simp::Cli::ProcessingError,
        "ERROR: `setfacl --restore=#{facl_file}` failed at '#{path}'"
      )
    end
  end
end
