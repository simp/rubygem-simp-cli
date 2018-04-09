require File.expand_path( '../action_item', File.dirname(__FILE__) )
require 'simp/cli/utils'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetProductionToSimpAction < ActionItem
    attr_accessor :primary_env_path, :secondary_env_path

    def initialize
      super
      @key                = 'puppet::set_production_to_simp'
      @description        = "Set default Puppet environment to 'simp'"

      # Normal Puppet environments path
      @primary_env_path   = Simp::Cli::Utils.puppet_info[:environment_path]

      # SIMP-specific secondary environments path
      @secondary_env_path = '/var/simp/environments'
    end

    def apply
      @applied_status = :failed
      success = set_primary_environment
      success = set_secondary_environment if success
      @applied_status = :succeeded if success
    end

    def apply_summary
      "Setting 'simp' to the Puppet default environment " +
        @applied_status.to_s
    end

    # Create link from <primary environments>/simp to
    # <primary environments>/production, backing up
    # <primary environments>/production to
    # <primary environments>.bak/production.<timestamp> if that
    # directory already exists
    # returns true if link and, if relevant, backup operation succeeded
    def set_primary_environment
      success = false
      production_path = File.join(@primary_env_path, 'production')
      simp_environment_path = File.join(@primary_env_path, 'simp')
      if File.exists?(@primary_env_path)
        if Dir.exists?(simp_environment_path)
          if File.exists?(production_path)
            if File.symlink?(production_path)
              debug( "Switching #{production_path} symlink to #{simp_environment_path}" )
              FileUtils.rm(production_path)
              Dir.chdir(@primary_env_path) do
                File.symlink('simp', 'production')
              end
              success = true
            else
              # have to backup outside of the normal environments directory, or installations
              # running R10K are likely to remove the backup
              backup_dir = "#{@primary_env_path}.bak"
              FileUtils.mkdir_p(backup_dir)
              group_id = File.stat(@primary_env_path).gid
              File.chown(nil, group_id, backup_dir)
              backup = File.join(backup_dir, "production.#{@start_time.strftime('%Y%m%dT%H%M%S')}")
              debug( "Backing up #{production_path} to #{backup}" )
              FileUtils.mv(production_path, backup)

              debug( "Linking #{production_path} to #{simp_environment_path}" )
              Dir.chdir(@primary_env_path) do
                File.symlink('simp', 'production')
              end
              success = true
            end
          else
            debug( "Linking #{production_path} to #{simp_environment_path}" )
            Dir.chdir(@primary_env_path) do
              File.symlink('simp', 'production')
            end
            success = true
          end
        else
          error( "\nERROR: 'simp' environment path not found: #{simp_environment_path}", [:RED] )
        end
      else
        error( "\nERROR: environments path not found: #{@primary_env_path}", [:RED] )
      end
      success
    end

    # Create link from <primary environments>/simp to
    # <primary environments>/production, unless
    # <primary environments>/production already exists
    # returns true when link operation was not required or was successful
    def set_secondary_environment
      success = false
      production_path = File.join(@secondary_env_path, 'production')
      if File.exists?(production_path)#TODO should we verify this is a directory or a link?
        debug( "Secondary environment link not required:" +
          " #{production_path} already exits" )
        success = true
      else
        simp_environment_path = File.join(@secondary_env_path, 'simp')
        if Dir.exists?(simp_environment_path)
          debug( "Linking #{production_path} to #{simp_environment_path}" )
          Dir.chdir(@secondary_env_path) do
            File.symlink('simp', 'production')
          end
          success = true
        else
          error( "\nERROR: 'simp' secondary environment path not found: #{simp_environment_path}", [:RED] )
        end
      end
      success
    end
  end
end
