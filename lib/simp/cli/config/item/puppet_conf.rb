require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::PuppetConf < ActionItem
    attr_accessor :file

    def initialize
      super
      @file        = File.join(::Utils.puppet_info[:config]['confdir'], 'puppet.conf')
      @key         = 'puppet::conf'
      @description = "Configures #{@file}; action-only."
    end

    def apply
      @applied_status = :failed
      say_green "Updating #{@file}..." if !@silent
      if @skip_apply
        say_yellow "WARNING: directed to skip Puppet configuration of #{file}" if !@silent
        @applied_status = :skipped
        return
      end

      success = true
      backup_file = "#{@file}.pre_simpconfig"
      FileUtils.cp("#{@file}", backup_file)
      `sed -i '/^\s*server.*/d'          #{@file}`
      `sed -i '/.*trusted_node_data.*/d' #{@file}`
      `sed -i '/.*digest_algorithm.*/d'  #{@file}`
      `sed -i '/.*stringify_facts.*/d'   #{@file}`

      %x{puppet config set trusted_node_data true}
      success &&= $?.success?
      %x{puppet config set digest_algorithm sha256}
      success &&= $?.success?
      %x{puppet config set stringify_facts false}
      success &&= $?.success?
      keylength = @config_items.fetch( 'use_fips', nil )? '2048' : '4096'
      %x{puppet config set keylength #{keylength}}
      success &&= $?.success?

      # do not die if config items aren't found
      puppet_server  = 'puppet.change.me'
      puppet_ca      = 'puppetca.change.me'
      puppet_ca_port = '8141'
      if item = @config_items.fetch( 'puppet::server', nil )
        puppet_server  = item.value
      end
      if item = @config_items.fetch( 'puppet::ca', nil )
        puppet_ca      = item.value
      end
      if item = @config_items.fetch( 'puppet::ca_port', nil )
        puppet_ca_port = item.value
      end

      %x{puppet config set server #{puppet_server}}
      success &&= $?.success?
      %x{puppet config set ca_server #{puppet_ca}}
      success &&= $?.success?
      %x{puppet config set ca_port #{puppet_ca_port}}
      success &&= $?.success?

      @applied_status = success ? :succeeded : :failed
    end

    def apply_summary
      "Update to Puppet settings in #{@file} #{@applied_status}"
    end
  end
end
