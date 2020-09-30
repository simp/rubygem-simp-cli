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
* This field may include 'LOCAL', to use the domain SIMP creates with
  the 'local' provider for EL6 or the 'files' provider for EL7.

IMPORTANT: For EL < 8, this field *MUST* have a valid domain or the sssd
service will fail to start.
}
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
        if Facter.value('os')['release']['major'] < "8"
          ['LOCAL']
        else
          []
        end
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
