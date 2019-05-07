require_relative '../item'
require_relative '../../utils'
require_relative 'cli_network_interface'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliNetworkNetmask < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::network::netmask'
      @description = %q{The netmask of the system.}
      @data_type   = :cli_params
      @__warning   = false
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_netmask x
    end

    # TODO: comment upon the hell-logic below
    # TODO: possibly refactor ip and netmask os_value into shared parent
    def get_os_value
      netmask = nil
      nic = get_item( 'cli::network::interface' ).value
      if nic || @fact
        @fact = @fact || "netmask_#{nic}"
        netmask = super
        if netmask.nil? and !@__warning
          warning = "WARNING: #{@key}: No Netmask found for NIC #{nic}"
          warn( warning, [:YELLOW] )
          @__warning = true
        end
      end
      netmask
    end

    def get_recommended_value
      os_value
    end
  end
end
