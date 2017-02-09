require File.expand_path( '../add_server_class_action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::AddLdapServerClassToServerAction < AddServerClassActionItem
    attr_accessor :dir

    def initialize
      @class_to_add = 'simp::server::ldap'  # pre-define, so description is set
      super
      @key          = 'puppet::add_ldap_server_class_to_server'
    end
  end
end
