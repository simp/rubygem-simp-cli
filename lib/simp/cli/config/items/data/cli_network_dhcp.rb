require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliNetworkDHCP < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::network::dhcp'
      @description = %q{Whether to use DHCP to retrieve your network settings ("dhcp") or to
use static network settings ("static").}
      @data_type   = :cli_params
    end

    def get_recommended_value
      'static' # a puppet master is always recommended to be static.
    end

    def validate( x )
      return ['dhcp', 'static' ].include?( x.to_s )
    end

    def not_valid_message
      'Valid answers are "static" or "dhcp"'
    end
  end
end
