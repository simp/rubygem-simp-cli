require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliNetworkGateway < Item
    def initialize
      super
      @key         = 'cli::network::gateway'
      @description = 'The default gateway.'
      @data_type   = :cli_params
    end


    # FIXME: make this a custom Fact?
    def get_os_value
      `ip route show 2>/dev/null` =~ /default\s*via\s*(.*)\s*dev/
      (($1 && $1.strip) || nil)
    end


    # Always recommend the default Gateway
    # TODO IDEA: recommend the primary nic's gateway?
    def get_recommended_value
      os_value
    end


    def validate( x )
      Simp::Cli::Config::Utils.validate_ip x
    end
  end
end
