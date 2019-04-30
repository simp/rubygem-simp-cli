require 'simp/cli/environment/dir_env'
require 'fileutils'

# Environment helper namespace
module Simp::Cli::Environment
  # Manages a Writable directory environment
  class WritableDirEnv < DirEnv
    def initialize(name, base_environments_path, opts)
      opts[:skeleton_path] ||= nil
      super(name, base_environments_path, opts)
    end

    # Create a new environment
    def create
      puts <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
        - [x] if environment is already deployed (#{@directory_path}/modules/*/ exist)
           - [x] THEN FAIL WITH HELPFUL MESSAGE
        - [ ] else
          - [ ] A1.2 create directory from skeleton

      TODO

      # Safety feature: Don't clobber a Puppet environment directory that already has content
      unless Dir.glob(File.join(@directory_path,'*')).empty?
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: A Writable environment directory with content already exists at '#{@directory_path}'"
        )
      end

      raise NotImplementedError, 'copy files or link directory'
    end

    # Fix consistency of Puppet directory environment
    #
    # @note This method is Tintentionally inert, as there has been some concern
    #   about whether this action is appropriate to implement for Writable
    #   environment directories.
    #
    #   The Puppet server originates the files found in this environment, and we
    #   shouldn't need to fix them unless something has gone very wrong indeed.
    #   Additionally, the potential for mayhem increases if we blithely monkey
    #   with the permissions of Puppet server's internal files.
    #
    #
    #   Current conclusion:
    #
    #   If the :copy logic of #create is implemented in a way that also copies
    #   files' permissions and attributes, a Writable env dir should never need
    #   user-initiated #fix actions.
    #
    #
    #   Exception:
    #
    #   If `simp environment import` is implemented as planned, ia #fix action
    #   may become useful to fix permissions when migrating SIMP Omni
    #   environments between different Puppet/PE servers.
    #
    def fix
      <<-TODO.gsub(%r{^ {6}}, '')
        TODO: #{self.class.to_s.split('::').last}.#{__method__}():
          - [x] if environment is not available (#{@directory_path} not found)
             - [x] THEN FAIL WITH HELPFUL MESSAGE
          - [x] A3.2.3 applies Puppet user settings & groups to
            - [x] $codedir/environments/$ENVIRONMENT/

      TODO

      ### # if environment is not available, fail with helpful message
      ### unless File.directory? @directory_path
      ###   fail(
      ###     Simp::Cli::ProcessingError,
      ###     "ERROR: Puppet environment directory not found at '#{@directory_path}'"
      ###   )
      ### end
      ### apply_puppet_permissions(File.join(@directory_path), false, true)
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
