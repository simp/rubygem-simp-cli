require_relative '../list_item'
require_relative '../../utils'
require_relative 'cli_network_ipaddress'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsDNSServers < ListItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp_options::dns::servers'
      @description = %Q{A list of DNS servers for the managed hosts.

If the first entry of this list is set to '127.0.0.1', then
all clients will configure themselves as caching DNS servers
pointing to the other entries in the list.

If you are using the SIMP ``resolv`` module, and the system is a DNS server
using the SIMP ``named`` module but you wish to have your node point to a
different DNS server for primary DNS resolution, then you MUST set
``resolv::named_server`` to ``true`` via Hiera.

This will get around the convenience logic that was put in place to handle
the caching entries and will not attempt to convert your system to a
caching DNS server.}
    end

    def get_os_value
      nameservers = []
      nmcli = Facter::Core::Execution.which('nmcli')
      if nmcli
        result = run_command("#{nmcli} -g IP4.DNS dev show", true)
        nameservers = result[:stdout].strip.split("\n")
        # have seen some extraneous blank lines in output, so make sure any
        # blank lines between entries are discarded
        nameservers.delete_if {|server| server.strip.empty? }
      end

      nameservers
    end

    # recommend:
    #   - os_value  when present, or:
    #   - ipaddress when present, or:
    #   - a must-change value
    def get_recommended_value
      if os_value.empty?
        if ip = @config_items.fetch( 'cli::network::ipaddress', nil )
          [ip.value]
        else
          ['8.8.8.8 (CHANGE THIS)']
        end
      else
        os_value
      end
    end

    # Each DNS server should be a valid IP address
    def validate_item item
      Simp::Cli::Config::Utils.validate_ip item
    end

    def not_valid_message
      "Invalid list of DNS server IP addresses."
    end
  end
end
