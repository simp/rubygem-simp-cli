require 'simp/cli/config/items/add_server_class_action_item'

module Simp::Cli::Config
  class Item::AddLdapServerClassToServerAction < AddServerClassActionItem

    def initialize
      @class_to_add = 'simp::server::ldap'  # pre-define, so description is set
      super
      @key          = 'puppet::add_ldap_server_class_to_server'
    end
  end
end
