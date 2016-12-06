require File.expand_path( '../integer_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsPuppetCAPort < IntegerItem
    def initialize
      super
      @key         = 'simp_options::puppet::ca_port'
      @description = %q{The port on which the Puppet Certificate Authority will listen
(8141 by default).}
    end

    def os_value
      Puppet.settings.setting( 'ca_port' ).value.to_i
    end

    # x is either the recommended value (Integer) or the query
    # result (String) prior to conversion to Integer
    def validate( x )
       (x.to_s =~ /^\d+$/ ? true : false ) && x.to_i > 0 && x.to_i <= 65535
    end

    def recommended_value
      8141
    end
  end
end
