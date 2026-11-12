# frozen_string_literal: true

require_relative '../password_item'
require_relative 'cli_local_priv_user'
require_relative '../../utils'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::CliLocalPrivUserPassword < PasswordItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key             = 'cli::local_priv_user_password'
      @description     = <<~EOM.strip
        The password of the local privileged user.

        The value entered is used to set the local user's password when the local
        user is created. The value stored in #{@key} is a
        hash of the password.
      EOM
      @data_type       = :cli_params
      @generate_option = :never_generate
    end

    # Fail before asking for a password that can't be hashed
    def query_ask
      unless Simp::Cli::Config::Utils.sha512_crypt_supported?
        raise Simp::Cli::ProcessingError, <<~EOM.strip
          #{Simp::Cli::Config::Utils::SHA512_CRYPT_UNSUPPORTED_MSG}.
          Set #{@key} to a SHA-512 hash of the password instead, either as
          #{@key}=<hash> on the command line or in an answers file (-a).
          'openssl passwd -6' generates such a hash.
        EOM
      end

      super
    end

    def query_prompt
      # make it clear we are asking for the password, not the hash
      username = get_item('cli::local_priv_user').value
      "'#{username}' password"
    end

    def validate(string)
      if @value.nil?
        # we should be dealing with an unencrypted password
        !string.to_s.strip.empty? && super
      else
        # the password hash has been pre-assigned
        Simp::Cli::Config::Utils.validate_password_sha512(string)
      end
    end

    def encrypt(string)
      Simp::Cli::Config::Utils.encrypt_password_sha512(string)
    end
  end
end
