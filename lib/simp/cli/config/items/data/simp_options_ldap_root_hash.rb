require File.expand_path( '../password_item',  File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdapRootHash < PasswordItem
    def initialize
      super
      @key                 = 'simp_options::ldap::root_hash'
      @description         = %Q{The LDAP Root password hash.

When set via 'simp config', it is generated from the password
entered on the command line.}
      @password_name       = 'LDAP Root'
      @data_type           = :server_hiera
      @generate_option     = :no_generate_as_default
    end

    def query_prompt
      'LDAP Root password'
    end

    def os_value
      if File.readable?('/etc/openldap/slapd.conf')
        `grep rootpw /etc/openldap/slapd.conf 2>/dev/null` =~ /\Arootpw\s+(.*)\s*/
        $1
      end
    end

    def encrypt( string, salt=nil )
      Simp::Cli::Config::Utils.encrypt_openldap_hash( string, salt )
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_openldap_hash( x ) ||
        ( !x.to_s.strip.empty? && super )
    end
  end
end
