require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapMaster < Item
    def initialize
      super
      @key         = 'simp_options::ldap::master'
      @description = %Q{The LDAP master in URI form (ldap://server or ldaps:://server).}
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
      if ( ( item =~ %r{^ldap[s]*://.+} ) ? true : false )
        i = item.sub( %r{^ldap[s]*://}, '' )
        result = ( Simp::Cli::Config::Utils.validate_hostname( i ) ||
                   Simp::Cli::Config::Utils.validate_fqdn( i )     ||
                   Simp::Cli::Config::Utils.validate_ip( i ) )
      end
      result
    end
  end
end
