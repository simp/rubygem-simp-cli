require_relative '../set_server_hieradata_action_item'
require_relative '../data/puppetdb_master_config_puppetdb_port'
require_relative '../data/puppetdb_master_config_puppetdb_server'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SetServerPuppetDBMasterConfigAction < SetServerHieradataActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @hiera_to_add = [
        'puppetdb::master::config::puppetdb_server',
        'puppetdb::master::config::puppetdb_port',
      ]
      super(puppet_env_info)
      @key = 'puppet::set_server_puppetdb_master_config'

      # override with a shorter message
      @description = 'Set PuppetDB master server & port in SIMP server <host>.yaml'
    end

    # override with a shorter message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Setting of PuppetDB master server & port in #{file} #{@applied_status}"
    end
  end
end
