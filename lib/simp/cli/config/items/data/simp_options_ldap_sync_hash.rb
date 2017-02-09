require File.expand_path( '../item',  File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapSyncHash < Item
    def initialize
      super
      @key         = 'simp_options::ldap::sync_hash'
      @description = %Q{}
      @skip_query  = true # generated from another Item, so no query required
    end

    def recommended_value
      encrypt( @config_items.fetch( 'simp_options::ldap::sync_pw' ).value )
    end

    def encrypt( string, salt=nil )
      Simp::Cli::Config::Utils.encrypt_openldap_hash( string, salt )
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_openldap_hash( x )
    end
  end
end
