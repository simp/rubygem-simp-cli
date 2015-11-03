require "resolv"
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::EnableSimpRepos < Item
    def initialize
      super
      @key         = 'simp::yum::enable_simp_repos'
      @description = %Q{If 'true', enable the default SIMP repositories.\nNOTE: this will automatically be 'false' if this master is the YUM server}
    end

    def recommended_value
      ! @config_items.fetch('is_master_yum_server').value
    end

    def query_ask
      @value = recommended_value
    end

    # internal method to change the system (returns the result of the apply)
    def apply; nil; end

    # don't be interactive!
    def validate( x ); true; end
  end
end
