require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsLdap < YesNoItem
    def initialize
      super
      @key         = 'simp_options::ldap'
      @description = %Q{Whether to use SIMP LDAP support on this system.

If you disable this, modules will not attempt to use LDAP where possible.}
    end

    def get_recommended_value
      'yes'
    end
  end
end
