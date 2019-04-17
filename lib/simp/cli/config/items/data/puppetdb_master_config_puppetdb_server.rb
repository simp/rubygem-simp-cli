require_relative '../item'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::PuppetDBMasterConfigPuppetDBServer < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'puppetdb::master::config::puppetdb_server'
      @description = %Q{The DNS name or IP of the PuppetDB server.}
      @data_type   = :server_hiera
    end

    def get_recommended_value
      "%{hiera('simp_options::puppet::server')}"
    end

    def validate string
      Simp::Cli::Config::Utils.validate_fqdn( string ) ||
      Simp::Cli::Config::Utils.validate_ip( string )   ||
      Simp::Cli::Config::Utils.validate_hiera_lookup( string )
    end
  end
end
