require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpServerAllowSimpUser < YesNoItem
    def initialize
      super
      @key         = 'simp::server::allow_simp_user'
      @description = %Q{Whether to allow local 'simp' user su and ssh privileges.

When SIMP is installed from ISO, a local user 'simp' is created to
prevent server lockout. This capability should only be enabled
when this user has been created.}

      @data_type   = :server_hiera
    end

    def get_recommended_value
      # NOTE: We ONLY want to use this Item when we want to turn off
      # the capability by default.
      'no'
    end
  end
end
