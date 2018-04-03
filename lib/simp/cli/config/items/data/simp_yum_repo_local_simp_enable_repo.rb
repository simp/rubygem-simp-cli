require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpYumRepoLocalSimpEnableRepo < YesNoItem
    def initialize
      super
      @key         = 'simp::yum::repo::local_simp::enable_repo'
      @description = 'Whether to enable the SIMP-managed, SIMP and
SIMP dependency YUM repository.'
      @data_type   = :server_hiera
    end

    # NOTE: The default is 'no', because we are only using this to
    # turn off the repo in the SIMP server host YAML.
    def get_recommended_value
      'no'
    end
  end
end
