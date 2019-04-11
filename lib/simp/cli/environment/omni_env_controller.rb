require 'simp/cli/environment/env'

# Puppetfile helper namespace
module Simp::Cli::Environment
  # Controller class to manage SIMP Omni environments
  class OmniEnvController
    def initialize(opts={}, env=nil)
      @opts = opts
      @environments = {
        puppet:    Env.new(env, opts),  # TODO: get PuppetEnv env factory
        secondary: Env.new(env, opts),  # TODO: get SecondaryEnv env factory, support backends
        writable:  Env.new(env, opts),  # TODO: get WritableEnv env factory, support backends
      }
    end

    # Create a new environment
    def create()
      @environments.each do |env_name, env_obj|
         env_obj.create
      end
    end

    # Update environment
    def update(); raise NotImplementedError; end

    # Remove environment
    def remove(); raise NotImplementedError; end

    # List current environments
    def list(); raise NotImplementedError; end

    # Fix consistency of environment
    def fix(); raise NotImplementedError; end

    # Validate consistency of environment
    def validate(); raise NotImplementedError; end
  end
end
