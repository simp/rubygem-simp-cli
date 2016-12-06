require File.expand_path( '../set_server_hieradata_action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SetServerLdapServerConfigAction < SetServerHieradataActionItem
    def initialize
      @hiera_to_add = [
        'simp_options::ldap::sync_pw',
        'simp_options::ldap::sync_hash',
        'simp_options::ldap::root_hash',
      ]
      super
      @key = 'puppet::set_server_ldap_server_config'

      # override with a shorter message
      @description = 'Set LDAP Sync & Root password hashes in SIMP server <host>.yaml'
    end

    # override with a shorter message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Setting of LDAP Sync & Root password hashes in #{file} #{@applied_status}"
    end
  end
end
