require_relative '../item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  class Item::CliNetworkInterface < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key               = 'cli::network::interface'
      @description       = 'The network interface to use to connect the SIMP server to the network.'
      @data_type         = :cli_params

      @fact_retrieved    = false  # whether 'networking' fact has been called
      @interface_hash    = {}     # key = interface, value is IPv4 address or nil
      @primary_interface = nil
    end

    # Add table of interfaces and their IP addresses to help user
    # choose what makes sense for their server.  Our 'recommendation'
    # is really a guess.
    def description
      "#{@description}\n#{interface_table}"
    end

    # Try to guess which NIC is likely to be used, preferring
    # a NIC that already has an IPv4 addresses
    def get_recommended_value
      recommended = nil

      if @primary_interface && interfaces[@primary_interface]
        recommended = @primary_interface
      else
        interfaces_with_ips = interfaces.dup.delete_if { |interface,ip| ip.nil? }
        if interfaces_with_ips.empty?
          # consider all interfaces, since none have IPv4 addresses
          devices = interfaces.keys.sort
        else
          # restrict to interfaces that have IPv4 addresses
          devices = interfaces_with_ips.keys.sort
        end
        recommended = (
          devices.select{|x| x.match(/^br/)}.first  ||
          # el7 systemd naming convention; Ethernet
          devices.select{|x| x.match(/^en/)}.first   ||
          # el7 biosdevname naming convention; embedded network interface
          devices.select{|x| x.match(/^em/)}.first   ||
          # el7 biosdevname naming convention; PCI card network interface
          devices.select{|x| x.match(/^p([0-9])+p([0-9])$/)}.first   ||
          # el6 kernel naming scheme
          devices.select{|x| x.match(/^eth/)}.first ||
          # anything else
          devices.first
         )
      end

      recommended
    end

    def validate( x )
      acceptable_values.include?( x )
    end

    def not_valid_message
      "Acceptable values:\n" + acceptable_values.map{ |x| "  #{x}" }.join("\n")
    end

    # helper method; provides a list of available NICs
    def acceptable_values
      interfaces.keys.sort
    end

    def get_interface_info
      network_info = Facter.value('networking')
      if network_info
        network_info['interfaces'].each do |interface,settings|
          next if interface == 'lo'
          @interface_hash[interface[interface]] = settings['ip']
        end
        @primary_interface = network_info['primary']
      end
      @fact_retrieved = true
    end

    def interfaces
      return @interface_hash if @fact_retrieved

      get_interface_info
      @interface_hash
    end

    def interface_table
      interface_hash = interfaces.dup
      return '' if interface_hash.empty?

      max_interface_length = interface_hash.keys.map(&:length).max
      max_interface_length = ['Interface'.length, max_interface_length].max
      output = [
        'AVAILABLE INTERFACES:',
        sprintf("    %-#{max_interface_length}s  %s", 'Interface', 'IP Address'),
        sprintf("    %-#{max_interface_length}s  %s", '---------', '----------')
      ]

      interface_hash.each do |interface,ipaddr|
        output << sprintf("    %-#{max_interface_length}s  %s", interface,
         (ipaddr.nil? ? 'N/A': ipaddr))
      end
       output.join("\n")
    end

    def primary_interface
      return @primary_interface if @fact_retrieved

      get_interface_info
      @primary_interface
    end
  end
end
