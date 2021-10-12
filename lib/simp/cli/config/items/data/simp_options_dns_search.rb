require_relative '../list_item'
require_relative 'cli_network_hostname'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsDNSSearch < ListItem
    attr_accessor :file
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp_options::dns::search'
      @description = %Q{The DNS domain search string.

Remember to put these in the appropriate order for your environment!}
      @file        = '/etc/resolv.conf'
    end

    def get_os_value
      # TODO: Figure out how to get this info from nmcli

      if File.exist?( @file )
        # NOTE: the resolver only uses the last of multiple search declarations
        File.readlines( @file ).select{ |x| x =~ /^search\s+/ }.last.to_s.gsub( /\bsearch\s+/, '').split( /\s+/ )
      else
        []
      end
    end

    # recommend:
    #   - os_value  when present, or:
    #   - cli::network::hostname when present, or:
    #   - a must-change value
    def get_recommended_value
      if os_value.empty?
        if fqdn = @config_items.fetch( 'cli::network::hostname', nil )
          [fqdn.value.split('.')[1..-1].join('.')]
        else
          ['domain.name (CHANGE THIS)']
        end
      else
        os_value
      end
    end

    # Each item must be a valid dns domain
    # TODO: def validate should notice if the search string will contain > 6
    # items or 256 chars
    def validate_item item
      Simp::Cli::Config::Utils.validate_domain item
    end

    def not_valid_message
      "Invalid list of DNS domains."
    end
  end
end
