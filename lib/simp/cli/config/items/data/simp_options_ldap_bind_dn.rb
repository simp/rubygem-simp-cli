require File.expand_path( '../item', File.dirname(__FILE__) )

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

    def recommended_value
      if @config_items.key?( 'cli::is_ldap_server') and
        @config_items.fetch( 'cli::is_ldap_server').value

        "cn=hostAuth,ou=Hosts,%{hiera('simp_options::ldap::base_dn')}"
      else
        nil
      end
    end
  end
end
