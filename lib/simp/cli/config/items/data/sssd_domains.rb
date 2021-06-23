require_relative '../list_item'
require_relative 'simp_options_ldap'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SssdDomains < ListItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'sssd::domains'
      @description = %Q{A list of domains for SSSD to use.

* When you are using SIMP-provided LDAP, this field should include 'LDAP',
  the name of the SSSD domain SIMP creates with the 'ldap' provider.

}

      @allow_empty_list = true
    end

    def get_recommended_value
      use_ldap   = get_item( 'simp_options::ldap' ).value
      if use_ldap
        # the only time simp_options::ldap will be true in
        # `simp config` is when we are setting up the SIMP-provided
        # LDAP server. So, it is appropriate to recommend the name
        # of the domain setup in the `simp` module.
        ['LDAP']
      else
        []
      end
    end

    def validate_item( x )
      x =~ /[-a-z]/i ? true : false
    end

    def not_valid_message
      "Invalid list of SSSD domains."
    end
  end
end
