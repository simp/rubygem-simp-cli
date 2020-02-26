require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/kv/operator_base'

# Class to delete a folder from a key/value store using the simp-simpkv Puppet
# module
class Simp::Cli::Kv::TreeDeleter < Simp::Cli::Kv::OperatorBase

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   simpkv backend configuration
  #
  # @param backend Name of key/value store in simpkv configuration
  #
  def initialize(env, backend)
    super(env, backend)
  end

  # Remove a folder in the key/value store
  #
  # @param folder Folder to list
  # @param global Whether folder is global
  #
  # @raise Simp::Cli::ProcessingError if the folder not exist or the
  #   remove fails
  #
  def deletetree(folder, global)
    logger.info("Removing folder #{full_store_path(folder, global)}")

    begin
      delete_folder(folder, global)
    rescue Exception => e
      err_msg = "Folder delete failed: #{e.message}"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  # Remove a folder in the key/value store via puppet apply of a
  # manifest that uses simpkv::deletetree()
  #
  # @param folder Folder to remove
  # @param global Whether folder is global
  #
  # @raise Simp::Cli::ProcessingError if the folder does not exist or the
  #   remove fails
  #
  def delete_folder(folder, global)
    logger.debug("Removing #{full_store_path(folder, global)} with a "\
      "puppet apply")

    args = "'#{folder}', #{simpkv_options(global)}"
    failure_message = "Folder '#{folder}' not found"
    opts = apply_options('Folder delete', failure_message)

    manifest =<<~EOM
      if simpkv::exists(#{args}) {
        simpkv::deletetree(#{args})
      } else {
        fail("#{failure_message}")
      }
    EOM

    Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
  end
end
