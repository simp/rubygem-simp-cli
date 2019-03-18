require 'ipaddr'
require 'resolv'
require_relative '../list_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsTrustedNets < ListItem
    def initialize
      super
      @key         = 'simp_options::trusted_nets'
      @description = %Q{A list of subnets to permit, in CIDR notation.

If you need this to be more (or less) restrictive for a given class,
you can override it in Hiera.}
      @allow_empty_list = false
    end

    def get_os_value
      # NOTE: the logic that would normally go here is in recommended_value
      # trusted_nets is an administrative concept, not an os configuration
      nil
    end

    # infer base network/CIDR values from IP/netmask
    def get_recommended_value
      address = get_item('cli::network::ipaddress').value
      nm      = get_item('cli::network::netmask').value

      # snarfed from:
      #   http://stackoverflow.com/questions/1825928/netmask-to-cidr-in-ruby
      subnet = IPAddr.new( nm ).to_i.to_s( 2 ).count('1')

      mucky_cidr = "#{address}/#{subnet}"
      cidr = "#{ IPAddr.new( mucky_cidr ).to_range.first.to_s}/#{subnet}"

      [ cidr ]
    end

    # validate subnet
    def validate_item( net )
      ### warn "'#{net}' doesn't end like a CIDR";
      return false if net !~ %r{/\d+$}

      ### warn "list item '#{net}' is not in proper CIDR notation";
      return false if net.split('/').size > 2

      subnet,cidr = net.split('/')

      # NOTE: if we support IPv6, we should redo netmask & validations
      ### warn "subnet '#{subnet}' is not a valid IP!";
      return false if !((subnet =~ Resolv::IPv4::Regex) || (subnet =~ Resolv::IPv6::Regex))

      ### warn "/#{cidr} is not a valid CIDR suffix";
      return false if !(cidr.to_i >= 0 && cidr.to_i <= 32)

      true
    end

    def not_valid_message
      "Invalid list of trusted networks in CIDR notation."
    end
  end
end
