require_relative '../yes_no_item'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SimpOptionsTcpwrappers < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key                 = 'simp_options::tcpwrappers'
      @description         = %Q{Set value for tcpwrappers on the simp server to false if OS > 7.}
      @data_type           = :server_hiera
      @skip_yaml           = true
    end

    def get_os_value
      if Facter.value('os')['release']['major']  > "7"
        false
      else
        true
      end
    end

    def get_recommended_value
      os_value
    end
  end
end
