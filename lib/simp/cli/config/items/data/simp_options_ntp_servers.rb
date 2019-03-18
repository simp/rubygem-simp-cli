require_relative '../list_item'
require_relative '../../utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsNTPServers < ListItem
    def initialize
      super
      @key              = 'simp_options::ntpd::servers'
      @description      =  %Q{Your network's NTP time servers.

A consistent time source is critical to a functioning public key
infrastructure, and thus your site security. **DO NOT** attempt to
run multiple production systems using individual hardware clocks!
}
      @no_ntp_warning  = %Q[Not specifying NTP servers in #{@key} can
negatively impact your site security.]
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

    def get_os_value( file='/etc/ntp.conf' )
      # TODO: make this a custom fact?
      servers = []
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
        info( "IMPORTANT: #{@no_ntp_warning}", [:RED] )

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
