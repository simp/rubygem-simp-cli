require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/kv/info_validator'
require 'simp/cli/kv/operator_base'
require 'tmpdir'

# Class to retrieve folder info from a key/value store using the simp-libkv
# Puppet module
class Simp::Cli::Kv::ListRetriever < Simp::Cli::Kv::OperatorBase

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   libkv backend configuration
  #
  # @param backend Name of key/value store in libkv configuration
  #
  def initialize(env, backend)
    super(env, backend)
  end

  # Retrieve the list of a folder's contents from the key/value store
  #
  # @param folder Folder to list
  # @param global Whether folder is global
  #
  # @return Hash containing the key/info pairs and list of sub-folders upon success
  #   * 'keys' attribute is a Hash of the key information in the folder
  #     * Each Hash key is a key found in the folder
  #     * Each Hash value is a Hash with 'value' and 'metadata' keys.
  #   * 'folders' attribute is an Array of sub-folder names
  #
  # @raise Simp::Cli::ProcessingError if the folder does not exist, the list
  #   operation failed or the information retrieved is malformed
  #
  def list(folder, global)
    logger.info("Retrieving list for #{full_store_path(folder, global)}")
    list = nil

    begin
      list = get_folder_list(folder, global)
      begin
        Simp::Cli::Kv::InfoValidator::validate_list_info(folder, list)
      rescue Simp::Cli::ProcessingError => e
        err_msg = "List info malformed: #{e}"
        raise Simp::Cli::ProcessingError, err_msg
      end
    rescue Exception => e
      err_msg = "Folder list failed: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end

    normalize_list(list)
  end

  # Retrieve a list of key info and sub-folders for a folder via puppet apply
  # of a manifest that uses libkv::list()
  #
  # @param folder Folder to list
  # @param global Whether folder is global
  #
  # @return Hash containing the key/info pairs and list of sub-folders upon success
  #   * 'keys' attribute is a Hash of the key information in the folder
  #     * Each Hash key is a key found in the folder
  #     * Each Hash value is a Hash with 'value' and 'metadata' keys.
  #   * 'folders' attribute is an Array of sub-folder names
  #
  # @raise if manifest apply to retrieve the list fails, the manifest result
  #   cannot be parsed as YAML
  #
  def get_folder_list(folder, global)
    logger.debug("Listing #{full_store_path(folder, global)} folder with a "\
      "puppet apply")

    tmpdir = Dir.mktmpdir( File.basename( __FILE__ ) )
    list = nil

    begin
      args = "'#{folder}', #{libkv_options(global)}"

      # persist to file, because content may be large and log scraping
      # is fragile
      result_file = File.join(tmpdir, 'list.yaml')
      failure_message = "Folder '#{folder}' not found"
      opts = apply_options('Folder list', failure_message)
      manifest =<<~EOM
        if libkv::exists(#{args}) {
          $list = libkv::list(#{args})
          file { '#{result_file}': content => to_yaml($list) }
        } else {
          fail("#{failure_message}")
        }
      EOM

      Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
      list = Simp::Cli::ApplyUtils::load_yaml(result_file, 'list', logger)
    ensure
      FileUtils.remove_entry_secure(tmpdir)
    end

    list
  end
end
