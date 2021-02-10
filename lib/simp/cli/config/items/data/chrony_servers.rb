require_relative '../list_item'
require_relative '../../utils'
require_relative 'cli_network_gateway'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::ChronyServers < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key          = 'chrony::servers'
      @description  =  'NTP time servers used by cronyd'
      @skip_query   = true # default value is correct, so no query required
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
