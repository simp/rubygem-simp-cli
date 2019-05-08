require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliIsSimpLdapServer < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::is_simp_ldap_server'
      @description = %q{Whether the SIMP server will also be a SIMP-provided LDAP server.

Enter 'yes' if want to use SIMP-provided LDAP and have the SIMP
server also be the LDAP server.

Enter 'no' if you do not want to use LDAP, you want to use some other
LDAP implementation, or you want to set up SIMP-provided LDAP in a
different configuration.  In these cases, you will need to set up
appropriate central authentication services manually before or
after bootstrapping.}

      @data_type   = :cli_params
    end

    def get_recommended_value
      'yes'
    end
  end
end
