require_relative '../class_item'

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
