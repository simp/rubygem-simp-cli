require 'simp/cli/config/items/add_server_class_action_item'

module Simp::Cli::Config
  class Item::AddSimpServerLdapClassToServerAction < AddServerClassActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @class_to_add = 'simp::server::ldap'  # pre-define, so description is set
      super(puppet_env_info)
      @key          = 'puppet::add_simp_server_ldap_class_to_server'
    end
  end
end
