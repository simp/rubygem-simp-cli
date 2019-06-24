require_relative '../action_item'
require_relative '../data/cli_network_dhcp'
require_relative '../data/cli_network_gateway'
require_relative '../data/cli_network_hostname'
require_relative '../data/cli_network_interface'
require_relative '../data/cli_network_ipaddress'
require_relative '../data/cli_network_netmask'
require_relative '../data/simp_options_dns_search'
require_relative '../data/simp_options_dns_servers'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::ConfigureNetworkAction < ActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key               = 'network::conf'
      @description       = 'Configure a network interface'
      @die_on_apply_fail = true
      @interface         = nil
      @category          = :system
    end

    def apply
      @applied_status = :failed
      cmd = nil

      dhcp      = get_item( 'cli::network::dhcp' ).value
      # BOOTPROTO=none is valid to spec; BOOTPROTO=static isn't
      bootproto = (dhcp == 'static') ? 'none' : dhcp
      @interface = get_item( 'cli::network::interface' ).value

      # apply the interface using the SIMP classes
      # NOTE: the "FACTER_ipaddress=XXX" helps puppet avoid a fatal error that
      #       occurs in the core ipaddress fact on offline systems.
      cmd = %Q(FACTER_ipaddress=XXX #{@puppet_apply_cmd} -e "network::eth{'#{@interface}': bootproto => '#{bootproto}', onboot => true)

      if bootproto == 'none'
        ipaddress   = get_item( 'cli::network::ipaddress'   ).value
        hostname    = get_item( 'cli::network::hostname'    ).value
        netmask     = get_item( 'cli::network::netmask'     ).value
        gateway     = get_item( 'cli::network::gateway'     ).value
        dns_search  = get_item( 'simp_options::dns::search' ).value
        dns_servers = get_item( 'simp_options::dns::servers').value

        resolv_domain = hostname.split('.')[1..-1].join('.')
        cmd += %Q{, }
        cmd += %Q@ipaddr => '#{ipaddress}', @
        cmd += %Q@netmask => '#{netmask}', @
        cmd += %Q@gateway => '#{gateway}' } @
        cmd += %Q@class{ 'resolv': @
        cmd += %Q@resolv_domain => '#{resolv_domain}', @
        cmd += %Q@servers => #{ format_puppet_array( dns_servers ) }, @
        cmd += %Q@search => #{ format_puppet_array( dns_search ) }, @
        cmd += %Q@named_autoconf => false, @
      end
      cmd += %Q@}"@
# TODO: maybe good ideas
#   - set $::domain with FACTER_domain=
#   - set resolv{ named_autoconf => false

      result = show_wait_spinner {
        execute(cmd)
      }

      if bootproto == 'dhcp'
        # The 'puppet apply' shutdown and then started the interface,
        # which should have resulted in the IP address being retrieved
        # via DHCP. This renders our networking facts obsolete.  So,
        # clear them out to ensure the latest facts will be used.
        Facter.clear

        # Make sure we have gotten an IP for this machine, or the
        # rest of the configuration can't be done
        ipaddr = Facter.value("ipaddress_#{@interface}")
        if ipaddr.nil? or ipaddr.empty?
          error("Failed to obtain IP address for #{@interface} from DHCP", [:RED])
          result = false
        end
      end

      @applied_status = :succeeded if result
    end

    def apply_summary
      "Configuration of #{@interface ? @interface : 'a'} network interface #{@applied_status}"
    end

   def format_puppet_array v
     v = [v] if v.kind_of? String
     "['#{v.join "','"}']"
   end
  end
end
