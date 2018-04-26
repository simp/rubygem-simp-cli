require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliNetworkDHCP < Item
    def initialize
      super
      @key         = 'cli::network::dhcp'
      @description = %q{Whether to use DHCP to set up your network ("static" or "dhcp").}
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
