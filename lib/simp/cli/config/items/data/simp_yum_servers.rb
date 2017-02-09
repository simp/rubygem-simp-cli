require File.expand_path( '../list_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpYumServers < ListItem
    def initialize
      super
      @key         = 'simp::yum::servers'
      @description = %Q{The YUM server(s) for OS and SIMP packages.}
    end

    def recommended_value
      if get_item( 'cli::has_local_yum_repos' ).value
        # Assume this is a normal ISO install for which this SIMP server
        # is both the puppet master and a YUM server.
        ["%{hiera('simp_options::puppet::server')}"]
      else
        # RPM or R10K install for which we have no idea where YUM repos are
        # located
        []
      end
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
      "Invalid list of YUM servers."
    end
  end
end
