require_relative '../action_item'
require_relative '../data/cli_network_dhcp'
require_relative '../data/cli_network_hostname'
require_relative '../data/cli_network_interface'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetHostnameAction < ActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key               = 'hostname::conf'
      @description       = 'Set hostname'
      @category          = :system
      @die_on_apply_fail = true
      @fqdn              = nil
    end

    def apply
      @applied_status = :failed
      @fqdn     = get_item( 'cli::network::hostname' ).value

      # TODO: replace this with 'puppet apply' + network::global
      info( 'Updating hostname' )
      success = execute("hostname #{@fqdn}")

      if (success)
        info( 'Updating /etc/sysconfig/network' )
        # only sed error is if file does not exist
        success = success && execute("sed -i '/HOSTNAME/d' /etc/sysconfig/network")
        success = success && execute("echo HOSTNAME=#{@fqdn} >> /etc/sysconfig/network")
      end

      if (success)
        info( 'Updating /etc/hostname' )
        begin
          File.open('/etc/hostname','w'){|fh| fh.puts(@fqdn)}
        rescue Errno::EACCES
          success = false
        end
      end

      if success && ( get_item( 'cli::network::dhcp' ).value == 'dhcp' )
        # restart the interface to pick up any domain changes associated
        # with the new hostname, if the interface is configured via DHCP
        interface = get_item( 'cli::network::interface' ).value
        info( "Restarting #{interface} interface to update domain info" )
        Simp::Cli::Utils::show_wait_spinner {
          success = success && execute("/sbin/ifdown #{interface}; /sbin/ifup #{interface} && wait && sleep 10")
        }

        # clear out any old networking-related facts
        Facter.clear
      end
      @applied_status = :succeeded if (success)
    end

    def apply_summary
      "Setting of hostname#{@fqdn ? ' to ' + @fqdn : ''} #{@applied_status}"
    end
  end
end
