require "resolv"
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::AddLdapToHiera < ActionItem
    attr_accessor :dir

    def initialize
      super
      @key         = 'puppet::add_ldap_to_hiera'
      @description = %Q{Adds simp::ldap_server to hieradata/hosts/puppet.your.domain.yaml (apply-only; noop).}
      @dir         = "/etc/puppet/environments/production/hieradata/hosts"
      @file        = nil
    end

    def apply
      success = true
      fqdn    = @config_items.fetch( 'hostname' ).value
      file    = File.join( @dir, "#{fqdn}.yaml")

      say_green 'Adding simp::ldap_server to the <domain>.yaml file' if !@silent

      if File.exists?(file)
        success = true
        yaml = File.open(file, "a") do |f|
          f.puts "  - 'simp::ldap_server'"
        end
      else
        success = false
        say_yellow "WARNING: file not found: #{file}"
      end
      success
    end


    def contains_ldap?( line )
      (line =~ /^\s*-\s+(([a-z_:'"]*::)*(open)*ldap|(open)*ldap[a-z_:'"]*)/m) ? true : false
    end
  end
end
