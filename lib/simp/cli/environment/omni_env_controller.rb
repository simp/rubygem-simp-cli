require 'simp/cli/environment/env'
require 'simp/cli/environment/puppet_dir_env'

# Puppetfile helper namespace
module Simp::Cli::Environment
  # Controller class to manage SIMP Omni environments
  class OmniEnvController
    def initialize(opts={}, env=nil)
      @opts = opts
      @environments = {}
      @opts[:types].each do |type, data|
        #TODO: different initialization per each type
        #TODO: honor backends
        case type
        when :puppet
          @environments[:puppet] = PuppetDirEnv.new(env,data)
        else
          @environments[type] = Env.new(env,data)
          warn("⋆⋆⋆★☆★ WARNING: IMPLEMENT <#{type}>Env")
        end
      end
    end

    # Create a new environment for each environment type
    def create()
      @environments.each do |env_type, env_obj|
        unless @opts[:types][env_type][:enabled]
          puts( "INFO: skipping #{env_type} environment" )
          next
        end
        puts "=== #{env_type} environment .create()"
        puts  @opts[:types][env_type].to_yaml
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
