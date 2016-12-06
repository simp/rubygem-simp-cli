require File.expand_path( '../integer_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::PuppetDBMasterConfigPuppetDBPort < IntegerItem
    def initialize
      super
      @key         = 'puppetdb::master::config::puppetdb_port'
      @description = %Q{The PuppetDB server port number.}
      @data_type   = :server_hiera
    end

    def recommended_value
      8139
    end

    # x is either the recommended value (Integer) or the query
    # result (String) prior to conversion to Integer
    def validate (x)
      ( x.to_s =~ /^\d+$/ ? true : false ) &&
      ( x.to_i > 1 && x.to_i < 65536 )
    end
  end
end
