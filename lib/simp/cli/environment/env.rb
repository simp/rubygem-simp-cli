require 'simp/cli/utils'

# Puppetfile helper namespace
module Simp::Cli::Environment
  # Abstract environment class
  class Env
    def initialize( name, opts )
      unless name =~ Simp::Cli::Utils::REGEXP_PUPPET_ENV_NAME
        fail( "ERROR: Illegal environment name: '#{name}'",'',
          'See: https://puppet.com/docs/puppet/6.4/environments_creating.html#concept-5441')
      end
      @name = name
      @opts = opts
    end

    # Create a new environment
    def create(); raise NotImplementedError; end

    # Update environment
    def update(); raise NotImplementedError; end

    # Remove environment
    def remove(); raise NotImplementedError; end

    # Validate consistency of environment
    def validate(); raise NotImplementedError; end

    # Fix consistency of environment
    def fix(); raise NotImplementedError; end

  end
end

