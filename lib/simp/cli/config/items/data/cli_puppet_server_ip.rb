require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliPuppetServerIP < Item
    def initialize
      super
      @key         = 'cli::puppet::server::ip'
      @description = %Q{The Puppet server's IP address.

This is used to configure /etc/hosts properly.}
      @data_type   = :internal
    end


    # Always recommend the configured IP
    def get_recommended_value
      get_item( 'cli::network::ipaddress' ).value
    end


    def validate( x )
      Simp::Cli::Config::Utils.validate_ip x
    end
  end
end
