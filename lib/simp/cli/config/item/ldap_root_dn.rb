require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LdapRootDn < Item
    def initialize
      super
      @key         = 'ldap::root_dn'
      @description = %Q{The LDAP root Distinguished Name.}

    end

    def os_value
      if File.readable?('/etc/openldap/slapd.conf')
        `grep rootdn /etc/openldap/slapd.conf` =~ /\Arootdn\s+[\"](.*)[\"]\s*/
        $1
      end
    end

    def recommended_value
      "cn=LDAPAdmin,ou=People,%{hiera('ldap::base_dn')}"
    end

    def validate( x )
      (x.to_s =~ /^cn=/) ? true : false
    end
  end
end
