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
      @description = %Q{Adds simp::ldap_server to hieradata/hosts/<host>.yaml; action-only.}
      @dir         = "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/hosts"
      @file        = nil
    end

    def apply
      @applied_status = :failed
      fqdn    = @config_items.fetch( 'hostname' ).value
      @file    = File.join( @dir, "#{fqdn}.yaml")

      say_green "Adding simp::ldap_server to the #{fqdn}.yaml file" if !@silent

      if File.exists?(@file)
        yaml = IO.readlines(@file)

        File.open(@file, "w") do |f|
          yaml.each do |line|
            line.chomp!
            if line =~ /^classes\s*:/
              f.puts line
              f.puts "  - 'simp::ldap_server'"
            else
              f.puts line unless contains_ldap?(line)
            end
          end
        end
        @applied_status = :succeeded
      else
        say_red "ERROR: file not found: #{@file}"
      end
    end

    def apply_summary
      "Addition of simp::ldap_server to #{@file ? File.basename(@file) : '<host>.yaml'} " +
        @applied_status.to_s
    end

    def contains_ldap?( line )
      #TODO Only care about simp::ldap_server, so should remove references to openldap?
      (line =~ /^\s*-\s+(([a-z_:'"]*::)*(open)*ldap|(open)*ldap[a-z_:'"]*)/m) ? true : false
    end
  end
end
