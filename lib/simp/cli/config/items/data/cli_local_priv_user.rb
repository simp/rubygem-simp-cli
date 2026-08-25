# frozen_string_literal: true

require_relative '../item'
require_relative '../../utils'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::CliLocalPrivUser < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'cli::local_priv_user'
      @description = <<~EOM.strip
        The local user to configure with `sudo` and `ssh` privileges to prevent server
        lockout after bootstrap.
      EOM

      @data_type = :cli_params
    end

    def validate(x)
      Simp::Cli::Config::Utils.validate_username(x)
    end
  end
end
