# frozen_string_literal: true

require_relative '../item'
require_relative '../../utils'
require_relative 'cli_is_simp_ldap_server'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapBindDn < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'simp_options::ldap::bind_dn'
      @description = %(The LDAP Bind Distinguished Name.)
    end

    def validate(x)
      Simp::Cli::Config::Utils.validate_ldap_cn_dn(x)
    end

    def not_valid_message
      "Valid LDAP Bind Distinguished Name must be a DN that begins with a 'cn=' RDN"
    end

    def get_recommended_value
      if @config_items.key?('cli::is_simp_ldap_server') &&
         @config_items.fetch('cli::is_simp_ldap_server').value

        "cn=hostAuth,ou=Hosts,%{hiera('simp_options::ldap::base_dn')}"
      else
        nil
      end
    end
  end
end
