require File.expand_path( '../action_item', File.dirname(__FILE__) )
require 'simp/cli/lib/utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::UpdatePuppetConfAction < ActionItem
    attr_accessor :file

    def initialize
      super
      @file        = File.join(::Utils.puppet_info[:config]['confdir'], 'puppet.conf')
      @key         = 'puppet::conf'
      @description = "Update Puppet settings"
    end

    def apply
      @applied_status = :failed

      backup_file = "#{@file}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
      debug( "Backing up #{@file} to #{backup_file}" )
      FileUtils.cp(@file, backup_file)
      group_id = File.stat(@file).gid
      File.chown(nil, group_id, backup_file)

      debug( "Updating #{@file}" )

      # sed only fails if file doesn't exist and we know @file exists
      # because the copy above didn't fail
      execute("sed -i '/^\s*server.*/d'          #{@file}")
      execute("sed -i '/.*trusted_node_data.*/d' #{@file}")
      execute("sed -i '/.*digest_algorithm.*/d'  #{@file}")
      execute("sed -i '/.*stringify_facts.*/d'   #{@file}")

      success = execute('puppet config set digest_algorithm sha256')
      keylength = get_item( 'simp_options::fips' ).value ? '2048' : '4096'
      success = success && execute("puppet config set keylength #{keylength}")

      # do not die if config items aren't found
      puppet_server  = 'puppet.change.me'
      puppet_ca      = 'puppetca.change.me'
      puppet_ca_port = '8141'
      if item = @config_items.fetch( 'simp_options::puppet::server', nil )
        puppet_server  = item.value
      end
      if item = @config_items.fetch( 'simp_options::puppet::ca', nil )
        puppet_ca      = item.value
      end
      if item = @config_items.fetch( 'simp_options::puppet::ca_port', nil )
        puppet_ca_port = item.value
      end

      success = success && execute("puppet config set server #{puppet_server}")
      success = success && execute("puppet config set ca_server #{puppet_ca}")
      success = success && execute("puppet config set ca_port #{puppet_ca_port}")

      @applied_status = success ? :succeeded : :failed
    end

    def apply_summary
      "Update to Puppet settings in #{@file} #{@applied_status}"
    end
  end
end
