require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpYumEnableSimpRepos < YesNoItem
    def initialize
      super
      @key         = 'simp::yum::enable_simp_repos'
      @description = 'Whether to enable remote SIMP YUM repositories'
      @data_type   = :server_hiera
    end

    # This action is only used when we want to enable remote 
    # YUM repos, so the default is 'yes'
    def recommended_value
      'yes'
    end
  end
end
