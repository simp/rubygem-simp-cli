require "resolv"
require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::NTPServers < ListItem
    def initialize
      super
      @key              = 'ntpd::servers'
      @warnings         = {
        :no_ntp            => "A consistent time source is critical to your systems' security.",
        :warning_hw_clocks => "DO NOT run multiple production systems using individual hardware clocks!",
      }
      @description      =  "Your network's NTP time servers.\n\n#{@warnings.values.join("\n")}"
      @allow_empty_list = true
    end

    def description
      extra = ''
      if @config_items.key? 'gateway'
        gateway  = @config_items.fetch('gateway').value
        extra = "\nFor many networks, the default gateway (#{gateway}) provides an NTP server."
      end
      "#{@description}#{extra}"
    end

    def os_value( file='/etc/ntp/ntpservers' )
      # TODO: make this a custom fact?
      # TODO: is /etc/ntp/ntpservers being used in recent versions of SIMP?
      servers = []
      if File.readable? file
        File.readlines( file ).map do |line|
          line.strip!
          if line !~ /^#/
            servers << line
          else
            nil
          end
        end.compact
      end
      servers
    end

    def recommended_value
      if (!os_value.empty?) && (os_value.first !~ /^127\./)
        os_value
      else
        nil
      end
    end

    # allow empty NTP servers, but reiterate warning because it's important.
    def validate list
      if !@silent && (list.is_a?(Array) || list.is_a?(String)) && list.empty?
        say_red( "IMPORTANT: #{@warnings.fetch(:no_ntp)}" )
        sleep 3  # TODO: should there be a standard timeout for Item delays?
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
