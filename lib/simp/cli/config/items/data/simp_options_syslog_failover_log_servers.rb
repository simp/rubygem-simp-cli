require_relative '../list_item'
require_relative '../../utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsSyslogFailoverLogServers < ListItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp_options::syslog::failover_log_servers'
      @description = 'Failover log server(s) in case your log servers(s) fail.'
      @allow_empty_list = true
    end

    def validate_item item
      ( Simp::Cli::Config::Utils.validate_hostname( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) ||
        Simp::Cli::Config::Utils.validate_ip( item ) )
    end

    def not_valid_message
      "Invalid list of failover log servers."
    end
  end
end
