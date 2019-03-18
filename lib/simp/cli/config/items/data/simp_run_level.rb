require File.expand_path( '../integer_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpRunLevel < IntegerItem
    def initialize
      super
      @key         = 'simp::runlevel'
      #TODO allow systemd options ('rescue','multi-user','graphical').  1-5 is
      # compatible both with # systemv (CentOS6) and systemd (CentOS7).
      @description = %Q{The default system runlevel (1-5).}
    end

    # x is either the recommended value (Integer) or the query
    # result (String) prior to conversion to Integer
    def validate( x )
      (x.to_s =~ /\A[1-5]\Z/) ? true : false
    end

    def not_valid_message
      'Must be a number between 1 and 5'
    end


    def get_os_value
      # FIXME: Facter fact
      %x{runlevel | awk '{print $2}'}.strip.to_i
    end

    def get_recommended_value
      3
    end
  end
end
