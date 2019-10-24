require_relative '../action_item'
require_relative '../data/simp_options_fips'
require_relative '../data/simp_options_puppet_ca'
require_relative '../data/simp_options_puppet_ca_port'
require_relative '../data/simp_options_puppet_server'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UpdatePuppetConfAction < ActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @file        = File.join(@puppet_env_info[:puppet_config]['config'])
      @key         = 'puppet::conf'
      @description = "Update Puppet settings"
      @category    = :puppet_global
    end

    def apply
      @applied_status = :failed

      backup_file = "#{@file}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
      info( "Backing up #{@file} to #{backup_file}" )
      FileUtils.cp(@file, backup_file)
      group_id = File.stat(@file).gid
      File.chown(nil, group_id, backup_file)

      info( "Updating #{@file}" )

      # These seds remove options that have been deprecated and cause Puppet to
      # emit `Setting ___ is deprecated` warning messages on each run:
      execute("sed -i '/^\s*server.*/d' #{@file}")
      execute("sed -i '/.*trusted_node_data.*/d' #{@file}")
      execute("sed -i '/.*digest_algorithm.*/d' #{@file}")
      execute("sed -i '/.*stringify_facts.*/d' #{@file}")
      execute("sed -i '/.*trusted_server_facts.*/d' #{@file}")

      keylength = get_item( 'simp_options::fips' ).value ? '2048' : '4096'
      puppet_server = get_item( 'simp_options::puppet::server' ).value
      puppet_ca = get_item( 'simp_options::puppet::ca' ).value
      puppet_ca_port = get_item( 'simp_options::puppet::ca_port' ).value

      success = Simp::Cli::Utils::show_wait_spinner {
        config_success = execute("puppet config set digest_algorithm #{Simp::Cli::PUPPET_DIGEST_ALGORITHM}")
        config_success = config_success && execute("puppet config set keylength #{keylength}")
        config_success = config_success && execute("puppet config set server #{puppet_server}")
        config_success = config_success && execute("puppet config set ca_server #{puppet_ca}")
        config_success = config_success && execute("puppet config set ca_port #{puppet_ca_port}")
        config_success
      }

      @applied_status = success ? :succeeded : :failed
    end

    def apply_summary
      "Update to Puppet settings in #{@file} #{@applied_status}"
    end
  end
end
