require_relative '../item'
require_relative 'cli_is_simp_ldap_server'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapBindDn < Item
    def initialize
      super
      @key         = 'simp_options::ldap::bind_dn'
      @description = %Q{The LDAP Bind Distinguished Name.}
    end

    def validate( x )
      (x.to_s =~ /^cn=/) ? true : false
    end

    def not_valid_message
      "Valid LDAP Bind Distinguished Name must begin with 'cn='"
    end

    def get_recommended_value
      if @config_items.key?( 'cli::is_simp_ldap_server') and
        @config_items.fetch( 'cli::is_simp_ldap_server').value

        "cn=hostAuth,ou=Hosts,%{hiera('simp_options::ldap::base_dn')}"
      else
        nil
      end
    end
  end
end
