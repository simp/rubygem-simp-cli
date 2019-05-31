# frozen_string_literal: true

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
      # Safety feature: Don't clobber a Puppet environment directory that already has content
      unless Dir.glob(File.join(@directory_path, '*')).empty?
        fail(
          Simp::Cli::ProcessingError,
          "ERROR: A Writable environment directory with content already exists at '#{@directory_path}'"
        )
      end

      case @opts[:strategy]

      # rubocop:disable Lint/EmptyWhen
      when :skeleton
        # noop
      when :copy
        copy_environment_files(@opts[:src_env], false)
      when :link
        fail NotImplementedError
      else
        fail("ERROR: Unknown Writable environment create strategy: '#{@opts[:strategy]}'")
      end
      # rubocop:enable Lint/EmptyWhen
    end

    # Fix consistency of Puppet directory environment
    #
    # @note This method is intentionally inert, as there has been some concern
    #   about whether this action is appropriate to implement for Writable
    #   environment directories.
    #
    #   The Puppet server originates the files found in this environment, and we
    #   shouldn't need to 'fix' them unless something has gone very wrong
    #   indeed.  Additionally, the potential for mayhem increases if we monkey
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
