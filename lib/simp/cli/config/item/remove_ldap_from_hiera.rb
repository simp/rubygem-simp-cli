require "resolv"
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RemoveLdapFromHiera < ActionItem
    attr_accessor :dir

    def initialize
      super
      @key         = 'puppet::remove_ldap_from_hiera'
      @description = %Q{Removes any ldap classes from hieradata/hosts/puppet.your.domain.yaml (apply-only; noop).}
      @dir         = "/etc/puppet/environments/production/hieradata/hosts"
      @file        = nil
    end

    def apply
      success = true
      fqdn    = @config_items.fetch( 'hostname' ).value
      file    = File.join( @dir, "#{fqdn}.yaml")

      say_green 'Removing ldap classes from the <domain>.yaml file' if !@silent

      if File.exists?(file)
        lines = File.open(file,'r').readlines

        File.open(file, 'w') do |f|
          lines.each do |line|
            line.chomp!
            f.puts line if !strip_line?(line)
          end
        end
      else
        success = false
        say_yellow "WARNING: file not found: #{file}"
      end
      success
    end


    def strip_line?( line )
      (line =~ /^\s*-\s+(([a-z_:'"]*::)*(open)*ldap|(open)*ldap[a-z_:'"]*)/m) ? true : false
    end
  end
end
