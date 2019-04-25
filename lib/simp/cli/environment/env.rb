require 'simp/cli/utils'

# Environment helper namespace
module Simp::Cli::Environment

  # Abstract environment class
  class Env
    def initialize(name, opts)
      unless name =~ Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME
        fail(ArgumentError, "ERROR: Illegal environment name: '#{name}'" + \
             "\n\nSee: https://puppet.com/docs/puppet/6.4/environments_creating.html#concept-5441")
      end

      @name = name
      @opts = opts
    end

    include Simp::Cli::Utils

    # Create a new environment
    def create
      fail NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Update environment
    def update
      fail NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Remove environment
    def remove
      fail NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Validate consistency of environment
    def validate
      fail NotImplementedError, "Implement .#{__method__} in a subclass"
    end

    # Fix consistency of environment
    def fix
      fail NotImplementedError, "Implement .#{__method__} in a subclass"
    end
  end
end
