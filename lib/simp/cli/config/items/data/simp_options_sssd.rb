require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsSSSD < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp_options::sssd'
      @description = %q{Whether to use SSSD.}
    end

    def get_recommended_value
      os_value || 'yes'
    end
  end
end
