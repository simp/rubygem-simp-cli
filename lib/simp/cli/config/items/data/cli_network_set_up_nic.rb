require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSetUpNIC < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::network::set_up_nic'
      @description = %Q{Whether to configure and activate this NIC now. A properly configured
NIC with associated hostname is required for SIMP to be bootstrapped.

If you enter 'yes', this will immediately, with appropriate prompts for
networking information, do the following:
- Configure the NIC for static or DHCP operation
- Set the hostname associated with the NIC
- **RESET** the interface to ensure proper activation of the NIC.

If you enter 'no', this will prompt you to enter all the NIC's networking
information, including the hostname, and `simp config` will **ASSUME** the
network has been configured and activated.

You should enter 'yes' if the interface has not yet been configured.
You may want to enter 'yes', if you want to reconfigure it and are **NOT**
logged into the server via this interface.}

      @data_type   = :cli_params
    end

    def get_recommended_value
      os_value || 'yes'
    end

    def query_ask
      nic = get_item( 'cli::network::interface' ).value
      super
    end

  end
end
