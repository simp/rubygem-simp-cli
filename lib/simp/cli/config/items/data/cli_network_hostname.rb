require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliNetworkHostname < Item
    def initialize
      super
      @key         = 'cli::network::hostname'
      @description = %q{The FQDN of the system.}
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
      # arbitrarily select the first entry.
      network_hostname = `hostname -A 2>/dev/null`.split[0]
      if network_hostname and validate( network_hostname )
        network_hostname
      else
        validate( os_value ) ? os_value : 'puppet.change.me'
      end
    end
  end
end
