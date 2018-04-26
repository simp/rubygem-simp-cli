require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapRootDn < Item
    def initialize
      super
      @key         = 'simp_options::ldap::root_dn'
      @description = %Q{The LDAP Root Distinguished Name.}
    end

    def get_recommended_value
      if @config_items.key?( 'cli::is_ldap_server') and
        @config_items.fetch( 'cli::is_ldap_server').value

        "cn=LDAPAdmin,ou=People,%{hiera('simp_options::ldap::base_dn')}"
      else
        nil
      end
    end

    def not_valid_message
      "Valid LDAP Root Distinguished Name must begin with 'cn='"
    end

    def validate( x )
      (x.to_s =~ /^cn=/) ? true : false
    end
  end
end
