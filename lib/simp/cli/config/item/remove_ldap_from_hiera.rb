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
      @description = %Q{Removes any ldap classes from hieradata/hosts/<host>.yaml; action-only.}
      @dir         = "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/hosts"
      @file        = nil
    end

    def apply
      @applied_status = :failed
      fqdn    = @config_items.fetch( 'hostname' ).value
      @file    = File.join( @dir, "#{fqdn}.yaml")

      say_green "Removing ldap classes from #{@file}" if !@silent

      if File.exists?(@file)
        lines = File.open(@file,'r').readlines

        File.open(@file, 'w') do |f|
          lines.each do |line|
            line.chomp!
            f.puts line if !strip_line?(line)
          end
        end
        @applied_status = :succeeded
      else
        say_red "ERROR: file not found: #{@file}"
      end
    end

    def apply_summary
      "Removal of ldap classes from #{@file ? File.basename(@file) : '<host>.yaml'} " +
        @applied_status.to_s
    end

    def strip_line?( line )
      #TODO Only care about simp::ldap_server, so should remove references to openldap
      (line =~ /^\s*-\s+(([a-z_:'"]*::)*(open)*ldap|(open)*ldap[a-z_:'"]*)/m) ? true : false
    end
  end
end
