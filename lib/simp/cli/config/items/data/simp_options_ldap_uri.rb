require_relative '../list_item'
require_relative 'cli_is_simp_ldap_server'
require_relative 'cli_network_hostname'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  class Item::SimpOptionsLdapUri < ListItem
    def initialize
      super
      @key         = 'simp_options::ldap::uri'
      @description = %Q{The list of OpenLDAP servers in URI form (ldap://server or ldaps:://server).}
    end

    def get_recommended_value
      result = [ 'ldap://FIXME' ]
      if @config_items.key?( 'cli::is_simp_ldap_server') and
        @config_items.fetch( 'cli::is_simp_ldap_server').value

        if item = @config_items.fetch( 'cli::network::hostname', nil )
          result = [ "ldap://#{item.value}" ]
        end
      end
      result
    end


    def validate_item item
      result = false
      if ( ( item =~ %r{^ldap[s]*://.+} ) ? true : false )
        i = item.sub( %r{^ldap[s]*://}, '' )
        result = ( Simp::Cli::Config::Utils.validate_hostname( i ) ||
                   Simp::Cli::Config::Utils.validate_fqdn( i )     ||
                   Simp::Cli::Config::Utils.validate_ip( i ) )
      end
      result
    end

    def not_valid_message
      "Invalid list of URIs for LDAP servers."
    end
  end
end
