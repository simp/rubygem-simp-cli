require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpSssdClientLdapServerType < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp::sssd::client::ldap_server_type'
      @description = <<~EOM
        The type of LDAP server that the system is communicating with.

        * Use `389ds` for servers that are 'Netscape compatible'. This includes
          FreeIPA, Red Hat Directory Server, and other Netscape DS-derived systems.
        * Use `plain` for servers that are 'regular LDAP' like OpenLDAP.
     EOM
    end

    def get_recommended_value
      if (Facter.value('os')['release']['major'] > '7')
        '389ds'
      else
        'plain'
      end
    end

    def validate( x )
      (x == '389ds') || (x == 'plain')
    end

    def not_valid_message
      "Invalid LDAP server type:  Must be '389ds' or 'plain'."
    end
  end
end
