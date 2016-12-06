require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapMaster < Item
    def initialize
      super
      @key         = 'simp_options::ldap::master'
      @description = %Q{This is the LDAP master in URI form (ldap://server).}
    end

    def recommended_value
      result = "ldap://FIXME"
      if @config_items.key?( 'cli::is_ldap_server') and
        @config_items.fetch( 'cli::is_ldap_server').value

        if item = @config_items.fetch( 'cli::network::hostname', nil )
          result = "ldap://#{item.value}"
        end
      end
      result
    end

    def validate item
      result = false
      if ( item =~ %r{^ldap://.+} ) ? true : false
        i = item.sub( %r{^ldap://}, '' )
        result = ( Simp::Cli::Config::Utils.validate_hostname( i ) ||
                   Simp::Cli::Config::Utils.validate_fqdn( i )     ||
                   Simp::Cli::Config::Utils.validate_ip( i ) )
      end
      result
    end
  end
end
