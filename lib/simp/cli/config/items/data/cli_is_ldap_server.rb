require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliIsLdapServer < YesNoItem
    def initialize
      super
      @key         = 'cli::is_ldap_server'
      @description = %q{Whether the SIMP server will also be the LDAP server.
}
      @data_type   = :cli_params
    end

    def recommended_value
      'yes'
    end
  end
end
