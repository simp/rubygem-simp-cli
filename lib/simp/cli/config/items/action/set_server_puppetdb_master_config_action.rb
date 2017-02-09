require File.expand_path( '../set_server_hieradata_action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SetServerPuppetDBMasterConfigAction < SetServerHieradataActionItem
    def initialize
      @hiera_to_add = [
        'puppetdb::master::config::puppetdb_server',
        'puppetdb::master::config::puppetdb_port',
      ]
      super
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
