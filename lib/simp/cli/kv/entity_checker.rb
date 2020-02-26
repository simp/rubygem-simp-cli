require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/kv/operator_base'

# Class to check the existence of a folder/key in a key/value store using
# the simp-simpkv Puppet module
class Simp::Cli::Kv::EntityChecker < Simp::Cli::Kv::OperatorBase

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   simpkv backend configuration
  #
  # @param backend Name of key/value store in simpkv configuration
  #
  def initialize(env, backend)
    super(env, backend)
  end

  # Check whether a folder/key exists in the key/value store
  #
  # @param entity Folder/key to locate
  # @param global Whether folder/key is global
  #
  # @return true if the folder/key exists
  #
  # @raise Simp::Cli::ProcessingError if the check fails
  #
  def exists(entity, global)
    logger.info("Checking for existence of #{full_store_path(entity, global)}")
    exists = nil

    begin
      exists = get_exists(entity, global)
    rescue Exception => e
      err_msg = "Folder/key exists failed: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end

    exists
  end

  # Check whether a folder/key exists via puppet apply of a manifest that uses
  # simpkv::exists()
  #
  # @param entity Folder/key to locate
  # @param global Whether folder/key is global
  #
  # @return true if the folder/key exists
  #
  # @raise Simp::Cli::ProcessingError if the check fails
  #
  def get_exists(entity, global)
    logger.debug("Checking existence of #{full_store_path(entity, global)} "\
      "with a puppet apply")

    args = "'#{entity}', #{simpkv_options(global)}"
    opts = apply_options('Folder/key exists')

    # such a trivial operation, going to use log scraping to gather result
    found_string = "'#{entity}' EXISTS"
    missing_string ="'#{entity}' DOES NOT EXIST"
    manifest =<<~EOM
      if simpkv::exists(#{args}) {
        warning("#{found_string}")
      } else {
        warning("#{missing_string}")
      }
    EOM

    result = Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
    !result[:stderr].match(/#{Regexp.escape(found_string)}/).nil?
  end
end
