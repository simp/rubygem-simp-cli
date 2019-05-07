require_relative('../password_item')

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOpenldapServerConfRootpw < PasswordItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key                 = 'simp_openldap::server::conf::rootpw'
      @description         = %Q{The salted LDAP Root password hash.

When set via 'simp config', this password hash is generated from
the password entered on the command line.}
      @password_name       = 'LDAP Root'
      @data_type           = :server_hiera
      @generate_option     = :no_generate_as_default
    end

    def query_prompt
      'LDAP Root password'
    end

    def encrypt( string, salt=nil )
      Simp::Cli::Config::Utils.encrypt_openldap_hash( string, salt )
    end

    def validate( x )
      if @value.nil?
        # we should be dealing with an unencrypted password
        ( !x.to_s.strip.empty? && super )
      else
        # the password hash has been pre-assigned
        Simp::Cli::Config::Utils.validate_openldap_hash( x )
      end
    end
  end
end
