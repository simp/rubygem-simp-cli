require "resolv"
require 'highline/import'
require File.expand_path( '../item',  File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::FailoverLogServers < ListItem
    def initialize
      super
      @key         = 'failover_log_servers'
      @description = 'Failover log server(s) in case your log servers(s) fail.'
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
  end
end
