require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/kv/operator_base'

# Class to set key info in a key/value store using the simp-simpkv Puppet
# module
class Simp::Cli::Kv::KeyStorer < Simp::Cli::Kv::OperatorBase

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   simpkv backend configuration
  #
  # @param backend Name of key/value store in simpkv configuration
  #
  def initialize(env, backend)
    super(env, backend)
  end

  # Set a key's stored info in the key/value store
  #
  # @param key Key to set
  # @param value Key's value
  # @param metadata Key's metadata Hash
  # @param binary Whether key has a binary value
  # @param global Whether key is global
  #
  # @raise Simp::Cli::ProcessingError if the key set fails
  #
  def put(key, value, metadata, binary, global)
    logger.info("Setting key info #{full_store_path(key, global)}")

    begin
      unless metadata.is_a?(Hash)
        err_msg = "Metadata for '#{key}' is not a Hash"
        raise Simp::Cli::ProcessingError, err_msg
      end

      if binary
        put_binary_key(key, value, metadata, global)
      else
        put_key(key, value, metadata, global)
      end
    rescue Exception => e
      err_msg = "Key set failed: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  # Set a key's stored info via puppet apply of a manifest that uses
  # simpkv::put(), when the key's value is a binary string
  #
  # @param key Key to store
  # @param value Key's Base64-encoded value
  # @param metadata Key's metadata Hash
  # @param global Whether key is global
  #
  # @raise Simp::Cli::ProcessingError if the key set fails
  #
  def put_binary_key(key, value, metadata, global)
    logger.debug("Setting #{full_store_path(key, global)} with a puppet apply")

    args = "'#{key}', $value_binary, #{metadata}, #{simpkv_options(global)}"
    opts = apply_options('Key put')
    manifest = <<~EOM
      $value_binary = Binary.new('#{value}', '%B')
      simpkv::put(#{args})
    EOM

    Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
  end

  # Set a key's stored info via puppet apply of a manifest that uses
  # simpkv::put(), when the key's value is not a binary string
  #
  # @param key Key to store
  # @param value Key's value
  # @param metadata Key's metadata Hash
  # @param global Whether key is global
  #
  # @raise Simp::Cli::ProcessingError if the key set fails
  #
  def put_key(key, value, metadata, global)
    logger.debug("Setting #{full_store_path(key, global)} with a puppet apply")

    # * The odd looking escape of single quotes is required because
    #   \' is a back reference in gsub.
    val = value.is_a?(String) ? "'#{value.gsub("'", "\\\\'")}'" : value
    args = "'#{key}', #{val}, #{metadata}, #{simpkv_options(global)}"
    opts = apply_options('Key put')
    manifest = "simpkv::put(#{args})"
    Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
  end
end
