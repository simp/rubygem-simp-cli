require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapBaseDn < Item
    def initialize
      super
      @key         = 'simp_options::ldap::base_dn'
      @description = %Q{The Base Distinguished Name of the LDAP server.}
    end

    def recommended_value
      if @config_items.key?( 'cli::is_ldap_server') and
        @config_items.fetch( 'cli::is_ldap_server').value

        if item = @config_items.fetch( 'cli::network::hostname', nil )
          item.value.split('.')[1..-1].map{ |domain| "dc=#{domain}" }.join(',')
        end
      else
        nil
      end
    end

    def validate( x )
      (x.to_s =~ /^dc=/) ? true : false
    end

    def not_valid_message
      "Valid LDAP Base Distinguished Name must begin with 'dc='"
    end
  end
end
