require File.expand_path( '../integer_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsPuppetCAPort < IntegerItem
    def initialize
      super

      @port = 8141

      if Simp::Cli::Utils.puppet_info[:is_pe]
        # We need to keep the port the puppet default if we're using PE
        @port = 8140
      end

      @key         = 'simp_options::puppet::ca_port'
      @description = %{The port on which the Puppet Certificate Authority will listen\n(#{@port} by default).}
    end

    def get_os_value
      Puppet.settings.setting( 'ca_port' ).value.to_i
    end

    # x is either the recommended value (Integer) or the query
    # result (String) prior to conversion to Integer
    def validate( x )
       (x.to_s =~ /^\d+$/ ? true : false ) && x.to_i > 0 && x.to_i <= 65535
    end

    def get_recommended_value
      @port
    end
  end
end
