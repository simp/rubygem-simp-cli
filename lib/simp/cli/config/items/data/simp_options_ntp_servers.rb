require_relative '../list_item'
require_relative '../../utils'
require_relative 'cli_network_gateway'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsNTPServers < ListItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key              = 'simp_options::ntp::servers'
      @description      =  %Q{Your network's NTP time servers.

A consistent time source is critical to a functioning public key
infrastructure, and thus your site security. **DO NOT** attempt to
run multiple production systems using individual hardware clocks!
}
      @no_ntp_warning  = %Q[Not specifying NTP servers in #{@key} can
negatively impact your site security. PKI depends upon sync'd time.]
      @allow_empty_list = true
    end

    def description
      extra = ''
      if @config_items.key? 'cli::network::gateway'
        gateway  = @config_items.fetch('cli::network::gateway').value
        extra = "\nFor many networks, the default gateway (#{gateway}) provides an NTP server."
      end
      "#{@description}#{extra}"
    end

    def get_os_value( chronydfile = '/etc/chrony.conf', ntpdfile = '/etc/ntp.conf' )
      servers = []
      file = nil
      if Simp::Cli::Utils.systemctl_running?('chronyd')
        file = chronydfile
      elsif Simp::Cli::Utils.systemctl_running?('ntpd')
        file = ntpdfile
      elsif File.exist?(chronydfile)
        file = chronydfile
      else
        file = ntpdfile
      end

      if File.readable? file
        File.readlines( file ).each do |line|
          match = line.match(/^server ([\w\.\-:]+)/)
          if match
            servers << match[1] unless (match[1] =~ /^127/)
          end
        end
      end
      servers
    end

    def get_recommended_value
      unless os_value.empty?
        os_value
      else
        nil
      end
    end

    # allow empty NTP servers, but reiterate warning because it's important.
    def validate list
      if (list.is_a?(Array) || list.is_a?(String)) && list.empty?
        notice( "IMPORTANT: #{@no_ntp_warning}", [:RED] )

        # if the value is not pre-assigned, pause to give the user time
        # to think about the impact of not specifying NTP servers
        pause(:info) if @value.nil?
      end
      super
    end

    def validate_item item
      ( Simp::Cli::Config::Utils.validate_ip( item ) ||
        Simp::Cli::Config::Utils.validate_fqdn( item ) )
    end

    def not_valid_message
      "Invalid list of NTP servers."
    end
  end
end
