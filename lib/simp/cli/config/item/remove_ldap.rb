require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RemoveLdap < ActionItem
    attr_accessor :file

    def initialize
      super
      # @key         = 'puppet::remove_ldap'
      @description = %Q{Removes any ldap references from hieradata/hosts/puppet.your.domain.yaml (apply-only; noop).}
      # @file        = '/etc/puppet/environments/production/hieradata/hosts/puppet.your.domain.yaml'
    end

    def apply
      success = true
      fqdn    = @config_items.fetch( 'hostname' ).value
      file    = "/etc/puppet/environments/production/hieradata/hosts/#{fqdn}.yaml"

      say_green 'Removing mentions of ldap from the <domain>.yaml file' if !@silent

      if File.exists?(file)
        success = `sed -i '/ldap/d' #{file}`
        success = $?.success?
      else
        success = false
        say_yellow "WARNING: file not found: #{file}"
      end
      success
    end
  end
end
