require 'simp/cli/config/items/add_server_class_action_item'

module Simp::Cli::Config
  class Item::AddSimpYumRepoInternetSimpServerClassToServerAction < AddServerClassActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @class_to_add = 'simp::yum::repo::internet_simp_server'  # pre-define, so description is set
      super(puppet_env_info)
      @key          = 'puppet::add_yum_repo_internet_simp_server'
    end
  end
end
