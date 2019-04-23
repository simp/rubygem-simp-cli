require 'simp/cli/environment/env'
require 'simp/cli/environment/puppet_dir_env'
require 'simp/cli/environment/secondary_dir_env'
require 'simp/cli/environment/writable_dir_env'

# Puppetfile helper namespace
module Simp::Cli::Environment
  # Controller class to manage SIMP Omni environments
  class OmniEnvController
    def initialize(opts = {}, env = nil)
      @opts = opts
      @environments = {}
      @opts[:types].each do |type, data|
        # TODO: honor backends
        # TODO: refactor into a Factory
        base_env_path = data[:environmentpath] || fail(ArgumentError, 'ERROR: no :environmentpath in opts')
        case type
        when :puppet
          @environments[:puppet]    = PuppetDirEnv.new(env, base_env_path, data)
        when :secondary
          @environments[:secondary] = SecondaryDirEnv.new(env, base_env_path, data)
        when :writable
          @environments[:writable]  = WritableDirEnv.new(env, base_env_path, data)
        else
          fail( "ERROR: Unrecognized environment type '#{env_type}'" )
        end
      end
    end

    # Create a new environment for each environment type
    def create
      each_environment 'create' do |env_type, env_obj|
        env_obj.create
      end

      # ensure environments are correct after creating them
      fix
    end

    # Update environment
    def update
      fail NotImplementedError
    end

    # Remove environment
    def remove
      fail NotImplementedError
    end

    # @return [Hash<Simp::Cli::Environment::Env>] current environments
    def list
      fail NotImplementedError
    end

    # Fix consistency of environment
    def fix
      each_environment 'fix' do |env_type, env_obj|
        env_obj.fix
      end
    end

    # Validate consistency of environment
    def validate
      fail NotImplementedError
    end

    private

    # Safely iterate through each environment
    # @param [String, nil] action_label  Optional string label to describle
    # @yieldparam [Symbol] env_type  The type of environment
    # @yieldparam [Simp::Cli::Environment::Env] env_obj  The environment object
    def each_environment(action_label=nil)
      @environments.each do |env_type, env_obj|
        label = action_label ? "(action: #{action_label}) " : ''
        unless @opts[:types][env_type][:enabled]
          puts("INFO: #{label}skipping #{env_type} environment ")
          next
        end
        yield env_type, env_obj
      end
    end
  end
end
