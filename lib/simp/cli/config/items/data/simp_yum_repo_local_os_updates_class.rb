require File.expand_path( '../class_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpYumRepoLocalOsUpdatesClass < ClassItem
    def initialize
      super
      @key = 'simp::yum::repo::local_os_updates'
    end
  end
end
