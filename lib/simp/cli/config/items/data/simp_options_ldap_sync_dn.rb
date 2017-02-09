require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapSyncDn < Item
    def initialize
      super
      @key         = 'simp_options::ldap::sync_dn'
      @description = %Q{The LDAP Sync Distinguished Name.}
    end

    def validate( x )
      (x.to_s =~ /^cn=/) ? true : false
    end

    def not_valid_message
      "Valid LDAP Sync Distinguished Name must begin with 'cn='"
    end

    def recommended_value
      if @config_items.key?( 'cli::is_ldap_server') and
        @config_items.fetch( 'cli::is_ldap_server').value

        "cn=LDAPSync,ou=Hosts,%{hiera('simp_options::ldap::base_dn')}"
      else
        nil
      end
    end

  end
end
