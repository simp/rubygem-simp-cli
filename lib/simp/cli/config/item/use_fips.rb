require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UseFips < YesNoItem
    def initialize
      super
      @key         = 'use_fips'
      @description = %q{enable fips on this system.}
    end

    def os_value
      Facter.value('fips_enabled') ? 'yes' : 'no'
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
