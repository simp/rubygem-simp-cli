# frozen_string_literal: true

require_relative '../item'
require_relative 'cli_is_simp_ldap_server'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapRootDn < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'simp_options::ldap::root_dn'
      @description = %(The LDAP Root Distinguished Name.)
    end

    def get_recommended_value
      if @config_items.key?('cli::is_simp_ldap_server') &&
         @config_items.fetch('cli::is_simp_ldap_server').value

        "cn=LDAPAdmin,ou=People,%{hiera('simp_options::ldap::base_dn')}"
      else
        nil
      end
    end

    def not_valid_message
      "Valid LDAP Root Distinguished Name must begin with 'cn='"
    end

    def validate(x)
      (x.to_s =~ %r{^cn=}) ? true : false
    end
  end
end
