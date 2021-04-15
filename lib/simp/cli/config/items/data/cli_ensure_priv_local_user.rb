require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliEnsurePrivLocalUser < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::ensure_priv_local_user'
      @description = <<~EOM.strip
        Whether to configure a privileged local user to prevent server lockout
        after bootstrap.

        SIMP by default disables remote logins for all users and disables `root`
        logins at the console. So, after bootstrap, you are very likely to lose
        access to this system, **unless** you configure a local user to have
        `sudo` and `ssh` access.

        Enter 'yes' if want to configure a local user to have `sudo` and `ssh`
        access after bootstrap.

        * You will select the local user to configure.
        * The local user will be created for you if it does not already exist.
        * If the user already exists and has ssh authorized keys, those keys
          will be copied to /etc/ssh/local_keys/, the default directory for
          local user SSH authorized keys files in SIMP.
      EOM

      @data_type   = :cli_params
    end

    def get_recommended_value
      'yes'
    end
  end
end
