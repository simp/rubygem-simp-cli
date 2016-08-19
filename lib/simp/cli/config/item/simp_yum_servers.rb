require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpYumServers < ListItem
    def initialize
      super
      @key         = 'simp::yum::servers'
      @description = %Q{The yum server(s) for SIMP packages.}
      @allow_empty_list = true
    end

    def recommended_value
      ["%{hiera('puppet::server')}"]
    end

    def validate_item item
      (
        Simp::Cli::Config::Utils.validate_hiera_lookup( item ) ||
        Simp::Cli::Config::Utils.validate_hostname( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) ||
        Simp::Cli::Config::Utils.validate_ip( item )
      )
    end

    def not_valid_message
      "Invalid list of yum servers."
    end
  end
end
