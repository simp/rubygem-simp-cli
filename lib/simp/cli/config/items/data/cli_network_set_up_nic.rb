require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSetUpNIC < YesNoItem
    def initialize
      super
      @key         = 'cli::network::set_up_nic'
      @description = %Q{Whether to activate this NIC now.}
      @data_type   = :cli_params
    end

    def recommended_value
      os_value || 'yes'
    end

    def query_ask
      nic = get_item( 'cli::network::interface' ).value
      super
    end

  end
end
