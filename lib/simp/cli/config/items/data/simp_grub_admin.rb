require_relative '../item'
require_relative '../../utils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpGrubAdmin < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'simp_grub::admin'
      @description = 'The GRUB 2 administrative username'
      @data_type   = :server_hiera
    end

    def get_recommended_value
      'root'
    end

    def validate( x )
      Simp::Cli::Config::Utils.validate_username(x)
    end
  end
end
