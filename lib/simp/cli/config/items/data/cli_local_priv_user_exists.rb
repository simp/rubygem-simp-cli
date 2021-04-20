require_relative '../yes_no_item'
require_relative 'cli_local_priv_user'
require 'etc'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliLocalPrivUserExists < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::local_priv_user_exists'
      @description = 'Whether the local priviledged user exists'
      @data_type  = :internal  # don't persist this as it needs to be
                               # evaluated each time simp config is run
    def get_os_value
        username   = get_item( 'cli::local_priv_user' ).value
        Etc.getpwnam(username)

        return 'yes'
      rescue ArgumentError => e
        return 'no'
      end
    end

    def get_recommended_value
      os_value
    end
  end
end
