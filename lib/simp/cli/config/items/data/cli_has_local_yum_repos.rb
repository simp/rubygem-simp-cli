require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliHasLocalYumRepos < YesNoItem
    attr_accessor :local_repo
    def initialize
      super
      @key         = 'cli::has_local_yum_repos'
      @description = %q{Whether the server has local system (OS) and SIMP YUM repos.

When SIMP is installed from and ISO, the system contains a
/etc/yum.repos.d/simp_filesystem.repo file that has YUM
configuration for local, OS and SIMP YUM repos.}
      @data_type  = :internal  # don't persist this as it needs to be
                               # evaluated each time simp config is run
      @local_repo = '/etc/yum.repos.d/simp_filesystem.repo'
    end


    def os_value
      (File.exist?(@local_repo) ? 'yes' : 'no')
    end

    def recommended_value
      os_value
    end
  end
end
