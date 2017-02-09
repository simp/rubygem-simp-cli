require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsPuppetServer < Item
    def initialize
      super
      @key         = 'simp_options::puppet::server'
      @description = %q{The Hostname or FQDN of the Puppet server.}
    end

    def os_value
      Puppet.settings.setting( 'server' ).value
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_hostname( x ) ||
      Simp::Cli::Config::Utils.validate_fqdn( x )
    end

    def recommended_value
      get_item( 'cli::network::hostname' ).value
    end
  end
end
