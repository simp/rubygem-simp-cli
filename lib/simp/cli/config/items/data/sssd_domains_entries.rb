# frozen_string_literal: true

require_relative '../item'
require_relative 'simp_options_ldap'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  # A special Item that never queries because its value is derived
  # from other Items.
  #
  # `sssd::domains_entries` is a Hash of SSSD domain name to that domain's
  # options (`{}` means present).  It replaces the deprecated `sssd::domains`
  # Array in simp/sssd 11.0.0 and later.  Unlike the Array, it is merged with
  # other Hiera layers, so a site can adjust one domain without restating the
  # rest.
  class Item::SssdDomainsEntries < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super
      @key         = 'sssd::domains_entries'
      @description = %(A Hash of the SSSD domains to manage, each mapped to its options.

* When you are using SIMP-provided LDAP, this should include 'LDAP',
  the name of the SSSD domain SIMP creates with the 'ldap' provider.
* An empty Hash ({}) means the domain is present with default options.
  Use { ensure: absent } to remove a domain.

)
    end

    def get_recommended_value
      use_ldap = get_item('simp_options::ldap').value
      if use_ldap
        # the only time simp_options::ldap will be true in
        # `simp config` is when we are setting up the SIMP-provided
        # LDAP server. So, it is appropriate to recommend the name
        # of the domain setup in the `simp` module.
        { 'LDAP' => {} }
      else
        {}
      end
    end

    # don't be interactive
    def query
      nil
    end

    def default_value_noninteractive
      default_value
    end

    def validate(x)
      x.is_a?(Hash)
    end

    def not_valid_message
      'Invalid Hash of SSSD domains.'
    end

    # Leave the key out when there are no domains, so the module's
    # defaults (and compliance profile) still apply.
    def to_yaml_s(include_auto_warning = false)
      return nil if @value.respond_to?(:empty?) && @value.empty?

      super
    end
  end
end
