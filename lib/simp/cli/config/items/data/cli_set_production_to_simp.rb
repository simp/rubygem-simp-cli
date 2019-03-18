require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliSetProductionToSimp < YesNoItem
    def initialize
      super
      @key         = 'cli::set_production_to_simp'
      @description = %Q{Whether to set default Puppet environment to 'simp'.

Links the 'production' environment to 'simp', after backing up the
existing production environment.}
      @data_type   = :cli_params
    end

    def get_recommended_value
      'yes'
    end
  end
end
