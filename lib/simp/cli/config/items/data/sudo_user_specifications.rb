require_relative '../item'
require_relative 'cli_local_priv_user'
require_relative 'cli_local_priv_user_exists'
require_relative 'cli_local_priv_user_has_ssh_authorized_keys'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config

  # A special Item that never queries because its value is derived
  # from other Items.
  #
  # Decided on this custom Item in lieu of a to-be-written HashItem (that reads
  # JSON strings) because the query and validation complexity of a HashItem is
  # not warranted, yet.  In other words, we have no reason to make the user
  # enter Hash values as of yet.
  class Item::SudoUserSpecifications < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'sudo::user_specifications'
      @description = '`sudo` user rules.'

      # make sure this does not get persisted to the answers file,
      # because we have no mechanism to validate it if the user
      # customizes it there
      @data_type = :internal
    end

    def get_recommended_value
      username = get_item( 'cli::local_priv_user' ).value
      password_required = true
      if ( get_item( 'cli::local_priv_user_exists' ).value &&
         get_item( 'cli::local_priv_user_has_ssh_authorized_keys' ).value )

        # May be a cloud user who does not have a password, so doesn't
        # make sense for sudo to prompt for a password
        password_required = false
      end

      {
        "#{username}_su" => {
          'user_list' => [ username ],
          'cmnd'      => [ 'ALL' ],
          'passwd'    => password_required,
          'options'   =>  { 'role' => 'unconfined_r' }
        }
      }
    end

    # don't be interactive
    def query;          nil;   end
    def validate( x );  true;  end
    def print_summary;  nil;   end
  end
end
