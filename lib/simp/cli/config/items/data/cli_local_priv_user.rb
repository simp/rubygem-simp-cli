require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliLocalPrivUser < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::local_priv_user'
      @description = <<~EOM.strip
        The local user to configure with `sudo` and `ssh` privileges to prevent server
        lockout after bootstrap.
      EOM

      @data_type  = :cli_params
    end

    def validate( x )
      # https://unix.stackexchange.com/questions/157426/what-is-the-regex-to-validate-linux-users
      x.match(/^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$/) != nil
    end
  end
end
