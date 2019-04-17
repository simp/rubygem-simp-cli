require_relative '../set_server_hieradata_action_item'
require_relative '../data/simp_yum_repo_local_os_updates_enable_repo'
require_relative '../data/simp_yum_repo_local_simp_enable_repo'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DisableServerLocalOsAndSimpYumReposAction < SetServerHieradataActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @hiera_to_add = [
        'simp::yum::repo::local_os_updates::enable_repo',
        'simp::yum::repo::local_simp::enable_repo'
      ]
      super(puppet_env_info)
      @key            = 'yum::repositories::local::disable'

      # override with a shorter message
      @description    = 'Disable duplicate YUM repos in SIMP server <host>.yaml'
    end

    # override with a better message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Disabling of duplicate OS & SIMP YUM repos in #{file} #{@applied_status}"
    end
  end
end
