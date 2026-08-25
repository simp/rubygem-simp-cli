# frozen_string_literal: true

require 'simp/cli/exec_utils'
require 'simp/cli/logging'
require 'simp/cli/utils'

# Environment helper namespace
module Simp::Cli::Environment
  # Abstract environment class
  class Env
    attr_reader :type

    include Simp::Cli::Logging

    # @param [Symbol] type  symbol indicating type of environment (e.g.,
    #   :puppet,  secondary...); used in log messages
    # @param [String] name  environment name
    # @param [Hash]   opts  options Hash
    def initialize(type, name, opts)
      unless Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME.match?(name)
        raise(ArgumentError, "ERROR: Illegal environment name: '#{name}'" \
                             "\n\nSee: https://puppet.com/docs/puppet/6.4/environments_creating.html#concept-5441")
      end

      @type = type
      @name = name
      @opts = opts
    end

    include Simp::Cli::Utils

    # Create a new environment
    def create
      raise NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Update environment
    def update
      raise NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Remove environment
    def remove
      raise NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Validate consistency of environment
    def validate
      raise NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Fix consistency of environment
    def fix
      raise NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Execute a command in a child process, log failure and return
    # a hash with the command status, stdout and stderr.
    #
    # @param [String] command  Command to be executed
    # @param [Boolean] ignore_failure  Whether to ignore failures.  When true and
    #   and the command fails, does not log the failure and returns
    #   a hash with :status = true
    #
    def run_command(command, ignore_failure = false)
      Simp::Cli::ExecUtils.run_command(command, ignore_failure, logger)
    end

    # Execute a command in a child process, log failure and return
    # whether command succeeded.
    #
    # @param [String] command  Command to be executed
    # @param [Boolean] ignore_failure  Whether to ignore failures.  When true and
    #   the command fails, does not log the failure and returns true.
    def execute(command, ignore_failure = false)
      Simp::Cli::ExecUtils.execute(command, ignore_failure, logger)
    end

    def trace(*args)
      logger.trace(*args)
    end

    def debug(*args)
      logger.debug(*args)
    end

    def info(*args)
      logger.info(*args)
    end

    def notice(*args)
      logger.notice(*args)
    end

    def warn(*args)
      logger.warn(*args)
    end

    def error(*args)
      logger.error(*args)
    end

    def fatal(*args)
      logger.fatal(*args)
    end

    def fail_unless_createable
      raise NotImplementedError, "Implement .#{__method__} in a subclass"
    end
  end
end
