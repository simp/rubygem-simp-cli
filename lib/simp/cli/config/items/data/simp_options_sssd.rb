require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsSSSD < YesNoItem
    def initialize
      super
      @key         = 'simp_options::sssd'
      @description = %q{Whether to use SSSD.}
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
