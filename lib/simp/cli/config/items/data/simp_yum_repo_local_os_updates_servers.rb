require File.expand_path( '../list_item', __dir__ )
require File.expand_path( '../../utils', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpYumRepoLocalOsUpdatesServers < ListItem
    def initialize
      super
      @key         = 'simp::yum::repo::local_os_updates::servers'
      @description = %Q{The YUM server(s) for SIMP-managed, OS Update packages.}
    end

    def get_recommended_value
      if get_item( 'cli::has_simp_filesystem_yum_repo' ).value
        # Assume this is a normal ISO install for which this SIMP server
        # is both the puppet master and a YUM server.
        ["%{hiera('simp_options::puppet::server')}"]
      else
        # RPM or R10K install for which we have no idea where YUM repos are
        # located
        ['FIXME']
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
