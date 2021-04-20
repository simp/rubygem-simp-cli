require_relative '../set_server_hieradata_action_item'
require_relative '../data/simp_server_allow_simp_user'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DisallowSimpUserAction < SetServerHieradataActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @hiera_to_add = [ 'simp::server::allow_simp_user' ]
      super(puppet_env_info)
      @key          = 'disallow::simp::server'

      # override base description with a more informative message
      @description  = "Disable inapplicable user config in SIMP server <host>.yaml"
    end

    # override base apply_summary with a more informative message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Disable of inapplicable user config in #{file} #{@applied_status}"
    end
  end
end
