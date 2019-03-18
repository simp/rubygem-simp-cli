require File.expand_path( '../yes_no_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliLogServersSpecified < YesNoItem
    def initialize
      super
      @key         = 'cli::log::servers:specified'
      @description = %Q{Whether syslog log servers are specified.

This is used to decide whether to prompt for forwarding log servers.}
      @data_type   = :internal
    end


    def get_recommended_value
      if get_item( 'simp_options::syslog::log_servers' ).value.empty?
        return 'no'
      else
        return 'yes'
      end
    end
  end
end
