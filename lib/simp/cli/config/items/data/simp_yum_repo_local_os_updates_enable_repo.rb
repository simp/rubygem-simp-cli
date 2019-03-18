require File.expand_path( '../yes_no_item', __dir__ )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpYumRepoLocalOsUpdatesEnableRepo < YesNoItem
    def initialize
      super
      @key         = 'simp::yum::repo::local_os_updates::enable_repo'
      @description = 'Whether to enable the SIMP-managed OS Update YUM repository.'
      @data_type   = :server_hiera
    end

    # NOTE: The default is 'no', because we are only using this to
    # turn off the repo in the SIMP server host YAML.
    def get_recommended_value
      'no'
    end
  end
end
