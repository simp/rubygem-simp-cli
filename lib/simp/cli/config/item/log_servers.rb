require "resolv"
require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::LogServers < ListItem
    def initialize
      super
      @key         = 'log_servers'
      @description = %Q{The log server(s) to receive forwarded logs. The default value is
to not forward any logs.

Only use hostnames here if at all possible. Default value is no forwarding.}
      @allow_empty_list = true
    end

    def os_value
      nil
    end

    def validate_item item
      ( Simp::Cli::Config::Utils.validate_hostname( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) ||
        Simp::Cli::Config::Utils.validate_ip( item ) )
    end

    def not_valid_message
      "Invalid list of log servers."
    end
  end
end
