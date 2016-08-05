require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::RenameFqdnYaml < ActionItem
    attr_accessor :file

    def initialize
      super
      @key         = 'puppet::rename_fqdn_yaml'
      @description = %q{Renames hieradata/hosts/puppet.your.domain.yaml template file to
 hieradata/hosts/<host>.yaml when no <host>.yaml file exists
(apply-only; noop).}
      @file        = '/etc/puppet/environments/simp/hieradata/hosts/puppet.your.domain.yaml'
      @new_file    = nil
    end

    def apply
      result   = true
      fqdn     = @config_items.fetch( 'hostname' ).value
      @new_file = File.join( File.dirname( @file ), "#{fqdn}.yaml" )
      say_green "Renaming #{File.basename(@file)} template to #{File.basename(@new_file)}" if !@silent

      if File.exists?(@file)
        if File.exists?( @new_file )
          say_green "INFO: Rename will not be done. #{@new_file} exists."
          say_yellow "WARNING: Review differences between #{File.basename(@file)} template" +
            " and\n         #{File.basename(@new_file)} for any updates."
          sleep(2)
        else
          File.rename( @file, @new_file )
        end
      else
        if File.exists?(@new_file)
          say_green "INFO: Rename not required.  Template file #{File.basename(@file)} " +
            "\n      no longer exists, but #{File.basename(@new_file)} does."
        else
          say_red "ERROR: Rename not possible. Neither template file #{File.basename(@file)}" +
            " or\n       #{File.basename(@new_file)} exist."
          result = false
        end
      end
      result
    end

    def apply_summary
      "Rename of #{File.basename(@file)} template to " +
        "#{@new_file ? File.basename(@new_file) : '<host>.yaml'} #{@applied_status.to_s}"
    end
  end
end
