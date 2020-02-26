require 'simp/cli/apply_utils'
require 'simp/cli/exec_utils'
require 'simp/cli/kv/info_validator'
require 'simp/cli/kv/operator_base'
require 'tmpdir'

# Class to retrieve info for a key from a key/value store using the simp-simpkv
# Puppet module
class Simp::Cli::Kv::KeyRetriever < Simp::Cli::Kv::OperatorBase

  # @param env Puppet environment.  Used to specify the location of non-global
  #   keys/folders in the key/value folder tree as well as where to find the
  #   simpkv backend configuration
  #
  # @param backend Name of key/value store in simpkv configuration
  #
  def initialize(env, backend)
    super(env, backend)
  end

  # Retrieve a key's stored info from the key/value store
  #
  # @param key Key to retrieve
  # @param global Whether key is global
  #
  # @return Hash of key information
  #   * 'value'- Key's value
  #   * 'metadata' - Key's metadata Hash; may be empty
  #
  # @raise Simp::Cli::ProcessingError if the key does not exist, the get
  #   operation failed or the information retrieved is malformed
  #
  def get(key, global)
    logger.info("Retrieving key info for #{full_store_path(key, global)}")
    info = nil

    begin
      info = get_key_info(key, global)
      begin
        Simp::Cli::Kv::InfoValidator::validate_key_info(key, info)
      rescue Simp::Cli::ProcessingError => e
        err_msg = "Key info malformed: #{e}"
        raise Simp::Cli::ProcessingError, err_msg
      end
    rescue Exception => e
      err_msg = "Key get failed: #{e}"
      raise Simp::Cli::ProcessingError, err_msg
    end

    normalize_key_info(info)
  end

  # Retrieve the info for a key info via puppet apply of a manifest using
  # simpkv::get()
  #
  # @param key Key to retrieve
  # @param global Whether key is global
  #
  # @return Hash of key information
  #   * 'value'- Key's value
  #   * 'metadata' - Key's metadata Hash; may be empty
  #
  # @raise Simp::Cli::ProcessingError if apply of manifest running
  #   simplib::passgen::get fails or the resulting YAML file containing the
  #   key info cannot be read
  #
  def get_key_info(key, global)
    logger.debug("Retrieving info for #{full_store_path(key,global)} with a "\
      "puppet apply")

    tmpdir = Dir.mktmpdir( File.basename( __FILE__ ) )
    key_info = nil

    begin
      args = "'#{key}', #{simpkv_options(global)}"

      # persist to file, because log scraping is fragile
      result_file = File.join(tmpdir, 'get.yaml')
      failure_message = "Key '#{key}' not found"
      opts = apply_options('Key get', failure_message)
      manifest =<<~EOM
        if simpkv::exists(#{args}) {
          $key_info = simpkv::get(#{args})
          file { '#{result_file}': content => to_yaml($key_info) }
        } else {
          fail("#{failure_message}")
        }
      EOM

      Simp::Cli::ApplyUtils::apply_manifest_with_spawn(manifest, opts, logger)
      key_info = Simp::Cli::ApplyUtils::load_yaml(result_file, 'get', logger)

      # Currently, simpkv::get() will omit 'metadata' attribute from returned
      # results if it is an empty Hash, but 'simp kv get' expects it to be
      # present.
      key_info['metadata'] = {} unless key_info.key?('metadata')
      key_info
    ensure
      FileUtils.remove_entry_secure(tmpdir)
    end

    key_info
  end
end
