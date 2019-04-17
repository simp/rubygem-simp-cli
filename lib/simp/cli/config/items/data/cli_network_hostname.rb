require_relative '../item'
require_relative '../../utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliNetworkHostname < Item
    def initialize
      super
      @key         = 'cli::network::hostname'
      @description = %q{The Fully Qualified Domain Name (FQDN) of the system.

This *MUST* contain a domain. Simple hostnames are not allowed.}
      @data_type   = :cli_params
      @fact        = 'fqdn'
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_fqdn x
    end

    def get_recommended_value
      # FIXME The 'fqdn' fact used for the os_value is not very sophisticated.
      # Specifically, it doesn't tell us the network hostname associated
      # with a DHCP-retrieved IP address. We attempt to get that information
      # here, so we can present the user with a better recommended value.
      # NOTE: `hostname -A` can return a list of hostnames.  Since we have
      # have no way of determining the most appropriate list entry, we
      # iterate through the hostnames provided to find the first one that
      # validates.
      network_hostname = nil
      `hostname -A 2>/dev/null`.split.each do |hostname|
        if validate( hostname )
          network_hostname = hostname
          break
        end
      end

      unless network_hostname
        network_hostname = (validate( os_value ) ? os_value : 'puppet.change.me')
      end

      network_hostname
    end
  end
end
