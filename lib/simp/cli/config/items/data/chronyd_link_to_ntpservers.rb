require_relative '../list_item'
require_relative '../../utils'
require_relative 'cli_network_gateway'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::ChronydNTPServersDefault < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key          = 'chronyd::servers'
      @description  =  %Q{Chrony module is not a simp module and does not default to simp_options values.  This setting links chronyd server settings to simp_options::ntp::server}
      @skip_query   = true
      @silent       = true
    end

    def validate(x)
      true
    end
    def get_recommended_value
      "%{alias('simp_options::ntp::servers')}"
    end

  end
end
