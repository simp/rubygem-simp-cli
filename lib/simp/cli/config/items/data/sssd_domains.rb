require File.expand_path( '../list_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SssdDomains < ListItem
    def initialize
      super
      @key         = 'sssd::domains'
      @description = %Q{A list of domains for SSSD to use.

* When `simp_options::ldap` is true, this field should include `LDAP`.
* When `simp_options::ldap` is false, this field must be a valid
  domain ('Local' and/or a custom domain) or the sssd service will
  fail to start.
}
    end

    def recommended_value
      use_ldap   = get_item( 'simp_options::ldap' ).value
      if use_ldap
        ['LDAP']
      else
        # make sure set to something valid, or sssd will not start
        ['Local']
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
