require_relative '../class_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpYumRepoLocalSimpClass < ClassItem
    def initialize
      super
      @key = 'simp::yum::repo::local_simp'
    end
  end
end
