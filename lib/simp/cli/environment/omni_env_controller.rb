# frozen_string_literal: true

require 'simp/cli/environment/env'
require 'simp/cli/environment/puppet_dir_env'
require 'simp/cli/environment/secondary_dir_env'
require 'simp/cli/environment/writable_dir_env'
require 'simp/cli/logging'

# Puppetfile helper namespace
module Simp::Cli::Environment
  # Controller class to manage SIMP Omni environments
  class OmniEnvController

    include Simp::Cli::Logging

    def initialize(opts = {}, env = nil)
      @opts = opts
      @env = env
      @environments = {}
      @opts[:types].each do |type, data|
        # TODO: honor backends?
        # TODO: refactor into a Factory
        base_env_path = data[:environmentpath] || fail(ArgumentError, 'ERROR: no :environmentpath in opts')
        opts_data = data.reject { |k, _v| k == :enabled }
        case type
        when :puppet
          @environments[:puppet]    = PuppetDirEnv.new(env, base_env_path, opts_data)
        when :secondary
          @environments[:secondary] = SecondaryDirEnv.new(env, base_env_path, opts_data)
        when :writable
          @environments[:writable]  = WritableDirEnv.new(env, base_env_path, opts_data)
        else
          fail("ERROR: Unrecognized environment type '#{env_type}'")
        end
      end
    end


    def fail_unless_createable
      errors = []
      each_environment 'pre-create' do |_env_type, env_obj|
        begin
          env_obj.fail_unless_createable
        rescue Simp::Cli::ProcessingError => e
          errors << e
          next
        end
      end
      unless errors.empty?
        fail Simp::Cli::ProcessingError, [
          "Cannot create environment because of errors encountered:",
          errors.map{|e| "  #{e.message}" }
        ].join("\n")
      end
    end
    # Create a new environment for each environment type
    def create
      # ensure environments are createable before proceeding
      fail_unless_createable

      logger.notice("Creating new environment '#{@env}'".bold)
      each_environment 'create' do |_env_type, env_obj|
        env_obj.create
      end

      each_environment('create') { |_t, env_obj| env_obj.create }
      fix  # ensure environments are correct after creating them
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
      logger.notice("Re-appling FACLs, SELinux contexts, & permissions to '#{@env}' environment".bold)
      each_environment 'fix' do |env_type, env_obj|
        if @opts[:types][env_type].fetch(:strategy,'') == :link
          logger.trace("TRACE: (action: fix) skipping fix of #{env_type} environment because strategy is :link")
          next
        end
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
    def each_environment(action_label = nil)
      @environments.each do |env_type, env_obj|
        label = action_label ? "(action: #{action_label}) " : ''
        unless @opts[:types][env_type][:enabled]
          logger.trace("TRACE: #{label}skipping #{env_type} environment")
          next
        end
        logger.trace("TRACE: #{label}applying #{env_type} environment")
        yield env_type, env_obj
      end
    end
  end
end
