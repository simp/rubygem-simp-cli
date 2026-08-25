# frozen_string_literal: true

require_relative '../list_item'
require_relative 'cli_is_simp_ldap_server'
require_relative 'cli_network_hostname'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapUri < ListItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'simp_options::ldap::uri'
      @description = %{The list of OpenLDAP servers in URI form (ldap://server or ldaps:://server).}
    end

    def get_recommended_value
      result = ['ldap://FIXME']
      if @config_items.key?('cli::is_simp_ldap_server') &&
         @config_items.fetch('cli::is_simp_ldap_server').value && (item = @config_items.fetch('cli::network::hostname', nil))
        result = ["ldap://#{item.value}"]
      end
      result
    end

    def validate_item(item)
      return false unless item.instance_of?(String)

      result = false
      if (item =~ %r{^ldaps*://.+}) ? true : false
        i = item.sub(%r{^ldaps*://}, '')
        result = Simp::Cli::Config::Utils.validate_hostname(i) ||
                 Simp::Cli::Config::Utils.validate_fqdn(i) ||
                 Simp::Cli::Config::Utils.validate_ip(i)
      end
      result
    end

    def not_valid_message
      'Invalid list of URIs for LDAP servers.'
    end
  end
end
