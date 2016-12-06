require File.expand_path( '../list_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  class Item::SimpOptionsLdapUri < ListItem
    def initialize
      super
      @key         = 'simp_options::ldap::uri'
      @description = %Q{The list of OpenLDAP servers in URI form (ldap://server).}
    end

    def recommended_value
      result = [ 'ldap://FIXME' ]
      if @config_items.key?( 'cli::is_ldap_server') and
        @config_items.fetch( 'cli::is_ldap_server').value

        if item = @config_items.fetch( 'cli::network::hostname', nil )
          result = [ "ldap://#{item.value}" ]
        end
      end
      result
    end


    def validate_item item
      ( item =~ %r{^ldap://.+} ) ? true : false &&
      (
        Simp::Cli::Config::Utils.validate_hostname( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item )     ||
        Simp::Cli::Config::Utils.validate_ip( item )
      )
    end

    def not_valid_message
      "Invalid list of URIs for LDAP servers."
    end
  end
end
