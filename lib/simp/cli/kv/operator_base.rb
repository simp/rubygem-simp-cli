require 'base64'
require 'highline/import'
require 'pathname'
require 'simp/cli/logging'
require 'simp/cli/utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Kv; end

# Base class for key/value store operations
class Simp::Cli::Kv::OperatorBase

  include Simp::Cli::Logging

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   libkv backend configuration
  #
  # @param backend Name of key/value store in libkv configuration
  #
  def initialize(env, backend)
    @env = env
    @backend = backend
    @puppet_info = Simp::Cli::Utils.puppet_info(@env)
  end

  # @return options appropriate for puppet apply via
  #   Simp::Cli::ApplyUtils::apply_manifest_with_spawn
  #
  # @param title Brief description of operation to use in error reporting
  # @param failure_message Error message to search for in the stderr output of
  #    a failed apply and then use as the (simplified) failure message if found
  #lib/simp/cli/kv/info_validator.rb
  def apply_options(title, failure_message=nil)
    opts = {
      :title         => title,
      :env           => @env,
      :fail          => true,
      :group         => @puppet_info[:config]['group'],
      :puppet_config => { 'vardir' => @puppet_info[:config]['vardir'] }
    }

    opts[:fail_filter] = failure_message unless failure_message.nil?
    opts
  end

  # @return Full effective path to the folder/key in the key/value store
  #
  # @param entity Folder/key
  # @param global Whether folder/key is global
  #
  def full_store_path(entity, global)
    path = global ? "/#{entity}" : "/#{@env}/#{entity}"
    Pathname.new(path).cleanpath.to_s
  end

  # @return Appropriate libkv options for the libkv function call
  #
  # @param global Whether folder/key is global
  #
  def libkv_options(global)
    {
      'backend'     => @backend,
      'environment' => (global ? '' : @env)
    }
  end

  # Convert a binary value into its JSON representation
  # @param info Key info Hash containing 'value' and 'metadata' attributes
  def normalize_key_info(info)
   normalized = info.dup
   if info['value'].is_a?(String) && (info['value'].encoding == Encoding::ASCII_8BIT)
     normalized['value'] = Base64.strict_encode64(info['value'])
     normalized['encoding'] = 'base64'
     normalized['original_encoding'] = 'ASCII-8BIT'
   end

   normalized
  end

  # Convert any keys that have binary values into their JSON value representations
  # @param list List Hash containing 'keys' and 'folders' attributes
  def normalize_list(list)
    normalized = { 'keys' => {}, 'folders' => list['folders'] }
    list['keys'].each do |key, info|
      normalized['keys'][key] = normalize_key_info(info)
    end

    normalized
  end
end
