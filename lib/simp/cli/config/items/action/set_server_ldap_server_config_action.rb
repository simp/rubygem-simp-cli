require File.expand_path( '../set_server_hieradata_action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SetServerLdapServerConfigAction < SetServerHieradataActionItem
    def initialize
      @hiera_to_add = [ 'simp_openldap::server::conf::rootpw' ]
      super
      @key = 'puppet::set_server_ldap_server_config'

      # override with a shorter message
      @description = 'Set LDAP Root password hash in SIMP server <host>.yaml'
    end

    # override with a shorter message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Setting of LDAP Root password hash in #{file} #{@applied_status}"
    end
  end
end
