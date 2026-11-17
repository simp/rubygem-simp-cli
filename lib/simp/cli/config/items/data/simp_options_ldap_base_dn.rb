# frozen_string_literal: true

require_relative '../item'
require_relative '../../utils'
require_relative 'cli_is_simp_ldap_server'
require_relative 'cli_network_hostname'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapBaseDn < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'simp_options::ldap::base_dn'
      @description = %(The Base Distinguished Name of the LDAP server.)
    end

    def get_recommended_value
      if @config_items.key?('cli::is_simp_ldap_server') &&
         @config_items.fetch('cli::is_simp_ldap_server').value

        if (item = @config_items.fetch('cli::network::hostname', nil))
          item.value.split('.')[1..].map { |domain| "dc=#{domain}" }.join(',')
        end
      else
        nil
      end
    end

    def validate(x)
      Simp::Cli::Config::Utils.validate_ldap_dn(x)
    end

    def not_valid_message
      "Invalid LDAP Base Distinguished Name. Use a DN such as 'dc=example,dc=com'"
    end
  end
end
