require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliUseInternetSimpYumRepos < YesNoItem
    attr_accessor :local_repo
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::use_internet_simp_yum_repos'
      @description = %q{Whether to configure SIMP nodes to use internet SIMP and
SIMP dependency YUM repositories.

When this option is enabled, Puppet-managed, YUM repository
configurations will be created for both the SIMP server and
SIMP clients. These configurations will point to official
SIMP repositories.}

      @data_type  = :cli_params
    end

    def get_recommended_value
      'yes'
    end
  end
end
