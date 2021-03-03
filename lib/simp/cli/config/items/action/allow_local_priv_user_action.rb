require_relative '../set_server_hieradata_action_item'
require_relative '../data/cli_local_priv_user'
require_relative '../data/pam_access_users'
require_relative '../data/selinux_login_resources'
require_relative '../data/sudo_user_specifications'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::AllowLocalPrivUserAction < SetServerHieradataActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @hiera_to_add = [
        'pam::access::users',
        'selinux::login_resources',
        'sudo::user_specifications'
      ]
      super(puppet_env_info)
      @key = 'puppet::allow_local_priv_user'

      # override base description with a more informative message
      @description = 'Allow ssh & sudo access to local user in SIMP server <host>.yaml'

      @merge_value = true  # all Items have Hash values and we want to add to
                           # existing Hashes with a shallow merge
    end

    # override base apply_summary with a more informative message
    def apply_summary
      username = get_item( 'cli::local_priv_user' ).value
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Configuring ssh & sudo for local user '#{username}' in #{file} #{@applied_status}"
    end
  end
end
