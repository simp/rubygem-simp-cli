require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/kv/operator_base'

# Class to delete a key from a key/value store using the simp-simpkv Puppet
# module
class Simp::Cli::Kv::KeyDeleter < Simp::Cli::Kv::OperatorBase

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   simpkv backend configuration
  #
  # @param backend Name of key/value store in simpkv configuration
  #
  def initialize(env, backend)
    super(env, backend)
  end

  # Remove a key in the key/value store
  #
  # @param key Key to remove
  # @param global Whether key is global
  #
  # @raise Simp::Cli::ProcessingError if the key does not exist or the
  #   remove fails
  #
  def delete(key, global)
    logger.info("Removing key #{full_store_path(key, global)}")

    begin
      delete_key(key, global)
    rescue Exception => e
      err_msg = "Key delete failed: #{e.message}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  # Remove a key in the key/value store via puppet apply of a
  # manifest that uses simpkv::delete()
  #
  # @param key Key to remove
  # @param global Whether key is global
  #
  # @raise Simp::Cli::ProcessingError if the key does not exist or the
  #   remove fails
  #
  def delete_key(key, global)
    logger.debug("Removing #{full_store_path(key, global)} with a puppet apply")

    args = "'#{key}', #{simpkv_options(global)}"
    failure_message = "Key '#{key}' not found"
    opts = apply_options('Key delete', failure_message)

    manifest =<<~EOM
      if simpkv::exists(#{args}) {
        simpkv::delete(#{args})
      } else {
        fail("#{failure_message}")
      }
    EOM

    Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
  end
end
