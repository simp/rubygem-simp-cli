require File.expand_path( '../yes_no_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSetUpNIC < YesNoItem
    def initialize
      super
      @key         = 'cli::network::set_up_nic'
      @description = %Q{Whether to activate this NIC now.

This will **reset** the interface, so enter 'no' if you are logged
in via the interface.}

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
