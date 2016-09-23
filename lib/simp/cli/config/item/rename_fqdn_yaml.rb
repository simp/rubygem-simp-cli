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
 hieradata/hosts/<host>.yaml when no <host>.yaml file exists; action-only.}
      @file        = "#{::Utils.puppet_info[:simp_environment_path]}/hieradata/hosts/puppet.your.domain.yaml"
      @new_file    = nil
    end

    def apply
      @applied_status = :failed
      result   = true
      fqdn     = @config_items.fetch( 'hostname' ).value
      @new_file = File.join( File.dirname( @file ), "#{fqdn}.yaml" )
      say_green "Renaming #{File.basename(@file)} template to #{File.basename(@new_file)}" if !@silent

      if File.exists?(@file)
        if File.exists?( @new_file )
          diff   = `diff #{@new_file} #{@file}`
          if diff.empty?
            @applied_status = :succeeded
            FileUtils.rm_rf(@file)
          else
            @applied_status = :deferred
            @applied_status_detail =
              "Manual merging of #{File.basename(@file)} into #{File.basename(@new_file)} may be required"

            message = %Q{WARNING: #{File.basename( @new_file )} exists, but differs from the template.
Review and consider updating:
#{diff}}
            say_yellow message
            sleep(2)
          end
        else
          File.rename( @file, @new_file )
          @applied_status = :succeeded
        end
      else
        if File.exists?(@new_file)
          @applied_status = :unnecessary
          @applied_status_detail = "Template already moved to #{File.basename(@new_file)}"
          say_magenta "INFO: Rename not required. #{@applied_status_detail}"
        else
          say_red "ERROR: Rename not possible. Neither template file " +
            "#{File.basename(@file)} or\n#{File.basename(@new_file)} exist."
        end
      end
    end

    def apply_summary
      "Rename of #{File.basename(@file)} template to " +
        "#{@new_file ? File.basename(@new_file) : '<host>.yaml'} #{@applied_status.to_s}" +
        "#{@applied_status_detail ? ":\n\t#{@applied_status_detail}" : ''}"
    end
  end
end
