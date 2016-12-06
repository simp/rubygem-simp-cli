require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpYumEnableOsRepos < YesNoItem
    def initialize
      super
      @key         = 'simp::yum::enable_os_repos'
      @description = 'Whether to enable remote system (OS) YUM repositories'
      @data_type   = :server_hiera
    end

    # This action is only used when we want to enable remote 
    # YUM repos, so the default is 'yes'
    def recommended_value
      'yes'
    end
  end
end
