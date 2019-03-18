require File.expand_path( '../class_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpYumRepoInternetSimpDependenciesClass < ClassItem
    def initialize
      super
      @key = 'simp::yum::repo::internet_simp_dependencies'
    end
  end
end
