require File.expand_path( '../item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsPuppetCA < Item
    def initialize
      super
      @key         = 'simp_options::puppet::ca'
      @description = 'The Puppet Certificate Authority.'
    end

    def get_os_value
      Puppet.settings.setting( 'ca_server' ).value
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_hostname( x ) ||
      Simp::Cli::Config::Utils.validate_fqdn( x ) ||
      Simp::Cli::Config::Utils.validate_ip( x )
    end

    def get_recommended_value
      get_item( 'cli::network::hostname' ).value
    end
  end
end
