require_relative '../item'
require_relative 'cli_local_priv_user'

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
  class Item::PamAccessUsers < Item
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'pam::access::users'
      @description = ( <<~EOM
        PAM remote access rules.

        Users allowed to ssh to the server and their corresponding origin
        restrictions.
        EOM
      ).strip

      # make sure this does not get persisted to the answers file,
      # because we have no mechanism to validate it if the user
      # customizes it there
      @data_type = :internal
    end

    def get_recommended_value
      username = get_item( 'cli::local_priv_user' ).value

      {
       username => { 'origins' => [ 'ALL' ] }
      }
    end

    # don't be interactive
    def query;          nil;   end
    def validate( x );  true;  end
    def print_summary;  nil;   end
  end
end
