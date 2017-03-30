require File.expand_path( '../item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpYumSimpUpdateUrl < Item
    def initialize
      super
      @key         = 'simp::yum::simp_update_url'
      @description = 'Full URL to a YUM repo for SIMP packages.'
    end

    def validate item
     ( item =~ %r{^http[s]*://.+} ) ? true : false
    end
  end
end
