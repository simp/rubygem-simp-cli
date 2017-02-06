require File.expand_path( '../action_item', File.dirname(__FILE__) )
require 'simp/cli/lib/utils'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CopySimpToEnvironmentsAction < ActionItem
    attr_accessor :source_dir, :dest_dir, :copy_script, :adapter_config

    def initialize
      super
      @key               = 'puppet::copy_simp_to_environments_action'
      @description       = 'Copy SIMP environment into Puppet environment path'
      @die_on_apply_fail = true
      @adapter_config    = '/etc/simp/adapter_config.yaml'
      @source_dir        = '/usr/share/simp'
      @dest_dir          = File.join(::Utils.puppet_info[:simp_environment_path])
      @copy_script       = '/usr/local/sbin/simp_rpm_helper'
    end

    def apply
      @applied_status = :failed

      enable_copy

      if Dir.exists?(@dest_dir)
        backup_dir = "#{::Utils.puppet_info[:environment_path]}.bak"
        backup = File.join(backup_dir, "simp.#{@start_time.strftime('%Y%m%dT%H%M%S')}")
        debug( "Backing up #{@dest_dir} to #{backup}" )
        FileUtils.mkdir_p(backup_dir)
        group_id = File.stat(::Utils.puppet_info[:environment_path]).gid
        File.chown(nil, group_id, backup_dir)
        FileUtils.mv(@dest_dir, backup)
      end

      simp_env_dir = File.join(@source_dir, 'environments', 'simp')
      debug( "Copying SIMP environment installed at #{simp_env_dir} to \n" +
        "    #{File.dirname(@dest_dir)}" )
      cmd = "#{@copy_script} --rpm_dir=#{simp_env_dir} --rpm_section='post' --rpm_status=1" +
        " --target_dir='.'"
      return unless show_wait_spinner {
        execute(cmd)
      }

      modules_dir = File.join(@source_dir, 'modules')
      debug( "Copying SIMP modules installed at #{modules_dir} to \n    #{File.dirname(@dest_dir)}" )
      module_list = Dir.glob(File.join(modules_dir, '*'))
      module_list.sort.each do |module_dir|
        debug( "Copying SIMP module #{File.basename(module_dir)} to \n    #{File.dirname(@dest_dir)}")
        cmd = "#{@copy_script} --rpm_dir=#{module_dir} --rpm_section='post' --rpm_status=1"
        return unless show_wait_spinner {
          execute(cmd)
        }
      end
      @applied_status = :succeeded
    end

    def apply_summary
      "Copy of SIMP environment into Puppet environment path #{@applied_status}"
    end

    def enable_copy
      # Simply overwrite this file. This will blow away any existing target_directory
      # setting, but, realistically, the rest of the logic in simp config won't work
      # unless the default value for target_directory is used.
      File.open(@adapter_config, 'w') do |file|
        file.puts <<EOM
---
# Target directory
# May be set to a fully qualified path or 'auto'
# If set to 'auto', the directory will be determined from puppet itself

# target_directory : 'auto'

# Copy the RPM data to the target directory

# copy_rpm_data : false
copy_rpm_data : true
EOM
      end
    end
  end
end
