require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::IsMasterYumServer < YesNoItem
    def initialize
      super
      @key         = 'is_master_yum_server'
      @description = %q{Is the master also used as a YUM server?

This option should be yes if the Puppet master (this system) will also act as a
YUM server for system packages or other custom repositories.
}
    end

    def recommended_value
      'yes'
    end
  end
end
