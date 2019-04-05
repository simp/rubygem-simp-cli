require 'simp/cli/config/items/action_item'
require 'simp/cli/utils'
require 'fileutils'

module Simp::Cli::Config
  class Item::CreateSimpServerFqdnYamlAction < ActionItem
    attr_accessor :template_file, :alt_file, :group

    def initialize
      super
      @key         = 'puppet::create_simp_server_fqdn_yaml'
      @description = 'Create SIMP server <host>.yaml from template'
      @die_on_apply_fail = true
      @template_file = File.join(Simp::Cli::Utils.simp_env_datadir, 'hosts', 'puppet.your.domain.yaml')
      @alt_file    = File.join('/', 'usr', 'share', 'simp', 'environments', 'simp',
        File.basename(Simp::Cli::Utils.simp_env_datadir), 'hosts', 'puppet.your.domain.yaml')
      @host_yaml   = nil
      @group       = Simp::Cli::Utils.puppet_info[:puppet_group]
      @category    = :puppet_env_server
    end

    def apply
      @applied_status = :failed
      result   = true
      fqdn     = get_item( 'cli::network::hostname' ).value
      @host_yaml = File.join( File.dirname( @template_file ), "#{fqdn}.yaml" )

      if !File.exists?(@template_file) and !File.exists?(@host_yaml) and File.exists?(@alt_file)
        # Can get here if
        # (1) RPM/ISO install (so /usr/share/simp exists)
        # (2) Operator runs simp config more than once but with different hostnames
        #     (e.g., tries to fix a typo by running again).
        extra_host_yaml = Dir.glob(File.join(File.dirname(@host_yaml), '*.yaml'))

        extra_host_yaml.each do |extra_yaml|
            debug("Other <host>.yaml file found: #{extra_yaml}")
        end

        FileUtils.cp(@alt_file, @template_file)
      end
      debug( "Creating #{File.basename(@host_yaml)} from #{File.basename(@template_file)} template" )

      if File.exists?(@template_file)
        if File.exists?( @host_yaml )
          diff   = `diff #{@host_yaml} #{@template_file}`
          if diff.empty?
            @applied_status = :succeeded
            FileUtils.rm_rf(@template_file)
          else
            @applied_status = :deferred
            @applied_status_detail =
              "Manual merging of #{File.basename(@template_file)} into pre-existing" +
              " #{File.basename(@host_yaml)} may be required"

            message = %Q{\nWARNING: #{File.basename( @host_yaml )} already exists, but differs from the template.
Review and consider updating:
#{diff}}
            warn( message, [:YELLOW] )
            pause(:warn)

            # backup this file because we will be modifying settings and/or the
            # class list in it via other ActionItems
            backup_host_yaml
          end
        else
          File.rename( @template_file, @host_yaml )
          # make sure permissions and ownership are correct
          FileUtils.chmod(0640, @host_yaml)
          begin
            FileUtils.chown(nil, @group, @host_yaml)
            @applied_status = :succeeded
          rescue Errno::EPERM, ArgumentError
            # This will happen if the user is not root or the group does
            # not exist.
            error( "\nERROR: Could not change #{@host_yaml} to #{@group} group", [:RED])
          end
        end
      else
        if File.exists?(@host_yaml)
          @applied_status = :unnecessary
          @applied_status_detail = "Template already moved to #{File.basename(@host_yaml)}"
          message = "#{File.basename(@host_yaml)} creation not required:\n" +
            "    #{@applied_status_detail}"
          debug( message, [:MAGENTA] )

          # backup this file because we will be modifying settings and/or the
          # class list in it via other ActionItems
          backup_host_yaml
        else
          error( "\nERROR: Creation of #{File.basename(@host_yaml)} not possible. Neither template file " +
            "#{File.basename(@template_file)} or\n#{File.basename(@host_yaml)} exist.", [:RED] )
        end
      end
    end

    def apply_summary
      'Creation of ' +
        "#{@host_yaml ? File.basename(@host_yaml) : 'SIMP server <host>.yaml'} #{@applied_status.to_s}" +
        "#{@applied_status_detail ? ":\n    #{@applied_status_detail}" : ''}"
    end

    def backup_host_yaml
      backup_file = "#{@host_yaml}.#{@start_time.strftime('%Y%m%dT%H%M%S')}"
      debug( "Backing up #{@host_yaml} to #{backup_file}" )
      FileUtils.cp(@host_yaml, backup_file)
      FileUtils.chown(nil, @group, backup_file)
    end
  end
end
