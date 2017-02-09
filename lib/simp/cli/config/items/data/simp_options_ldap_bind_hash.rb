require File.expand_path( '../item',  File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapBindHash < Item
    def initialize
      super
      @key         = 'simp_options::ldap::bind_hash'
      @description = %Q{The salted LDAP Bind password hash.}
      @skip_query  = true  # generated from another Item, so no query required
    end

    def recommended_value
      encrypt( @config_items.fetch( 'simp_options::ldap::bind_pw' ).value )
    end

    def encrypt( string, salt=nil )
      Simp::Cli::Config::Utils.encrypt_openldap_hash( string, salt )
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_openldap_hash( x )
    end
  end
end
