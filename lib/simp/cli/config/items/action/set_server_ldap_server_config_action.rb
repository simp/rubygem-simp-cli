require_relative '../set_server_hieradata_action_item'
require_relative '../data/simp_openldap_server_conf_rootpw'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SetServerLdapServerConfigAction < SetServerHieradataActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @hiera_to_add = [ 'simp_openldap::server::conf::rootpw' ]
      super(puppet_env_info)
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
