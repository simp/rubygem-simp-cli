require 'simp/cli/errors'
require 'base64'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Kv; end

module Simp::Cli::Kv::InfoValidator

  def self.validate_binary_key_info(key, info)
    if info.key?('encoding')
      unless info['value'].is_a?(String)
        err_msg = "'encoding' found for '#{key}'.\n"
        err_msg += ">> 'encoding' reserved for binary values"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end

    if info.key?('original_encoding')
      unless info['value'].is_a?(String)
        err_msg = "'original_encoding' found for '#{key}'.\n"
        err_msg += ">> 'original_encoding' reserved for binary values"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end

    if info.key?('encoding')
      unless info.key?('original_encoding')
        err_msg = "Missing 'original_encoding' for '#{key}' with binary value"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end

    if info.key?('original_encoding')
      unless info.key?('encoding')
        err_msg = "Missing 'encoding' for '#{key}' with binary value"
        raise Simp::Cli::ProcessingError, err_msg
      end
    end

    begin
      Base64.strict_decode64(info['value'])
    rescue ArgumentError => e
      err_msg = "'value' for '#{key}' does not contain strict Base64 encoding"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

  def self.validate_key_info(key, info)
    unless info.is_a?(Hash)
      err_msg = "Info for '#{key}' is not a Hash"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless info.key?('value')
      err_msg = "Missing 'value' attribute for '#{key}'"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless info.key?('metadata')
      err_msg = "Missing 'metadata' attribute for '#{key}'"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless info['metadata'].is_a?(Hash)
      err_msg = "'metadata' for '#{key}' is not a Hash"
      raise Simp::Cli::ProcessingError, err_msg
    end

    if info.key?('encoding') || info.key?('original_encoding')
      validate_binary_key_info(key, info)
    end
  end

  def self.validate_list_info(folder, info, validate_keys = false)
    unless info.is_a?(Hash)
      err_msg = "Info for '#{folder}' is not a Hash"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless info.key?('keys')
      err_msg = "Missing 'keys' attribute for '#{folder}'"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless info['keys'].is_a?(Hash)
      err_msg = "'keys' for '#{folder}' is not a Hash"
      raise Simp::Cli::ProcessingError, err_msg
    end

    if validate_keys
      info['keys'].each do |key,info|
        begin
          validate_key_info(key, info)
        rescue Simp::Cli::ProcessingError => e
          err_msg = "#{e} in '#{folder}' list results"
          raise Simp::Cli::ProcessingError, err_msg
        end
      end
    end

    unless info.key?('folders')
      err_msg = "Missing 'folders' attribute for '#{folder}'"
      raise Simp::Cli::ProcessingError, err_msg
    end

    unless info['folders'].is_a?(Array)
      err_msg = "'folders' for '#{folder}' is not an Array"
      raise Simp::Cli::ProcessingError, err_msg
    end
  end

end
