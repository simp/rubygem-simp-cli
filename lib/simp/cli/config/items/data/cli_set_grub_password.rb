require File.expand_path( '../yes_no_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSetGrubPassword < YesNoItem
    def initialize
      super
      @key         = 'cli::set_grub_password'
      @description = %Q{Whether to set the GRUB password on this system.}
      @data_type   = :cli_params
    end

    def recommended_value
      os_value || 'yes'
    end
  end
end
