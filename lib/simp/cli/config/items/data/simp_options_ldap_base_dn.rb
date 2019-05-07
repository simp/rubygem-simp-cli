require_relative '../item'
require_relative 'cli_is_simp_ldap_server'
require_relative 'cli_network_hostname'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapBaseDn < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp_options::ldap::base_dn'
      @description = %Q{The Base Distinguished Name of the LDAP server.}
    end

    def get_recommended_value
      if @config_items.key?( 'cli::is_simp_ldap_server') and
        @config_items.fetch( 'cli::is_simp_ldap_server').value

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
