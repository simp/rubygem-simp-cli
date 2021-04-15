require_relative '../action_item'
require_relative '../data/cli_local_priv_user'
require_relative '../data/cli_network_hostname'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::WarnVerifyUserAccessAfterBootstrapAction < ActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'login::verify::access'
      @description = 'Verify access after `simp bootstrap`'
      @category    = :sanity_check
    end

    def apply
      username = get_item('cli::local_priv_user').value
      hostname = get_item( 'cli::network::hostname' ).value
      warning_message = <<~DOC

        #########################################################################
        #                            CRITICAL WARNING                           #
        #########################################################################

        **After** `simp bootstrap` but **before** you reboot the server or
        close the terminal, it is imperative that you verify user '#{username}'
        access as follows:

        Using a NEW SSH SESSION OR TERMINAL (do NOT close your working session)

        * Log in as '#{username}':

           ssh #{username}@#{hostname}

        * sudo to root:

           sudo su - root

            +-------------------------------------------------------------+
            | If your user cannot ssh into the server and sudo to `root`  |
            |                                                             |
            | * DO NOT reboot the server until you resolve the problem!   |
            |                                                             |
            | * DO NOT log out of your initial work terminal until you    |
            |   resolve the problem!                                      |
            +-------------------------------------------------------------+
      DOC

      @applied_status = :deferred
      warn( warning_message.yellow )
      pause(:warn, 6)
    end

    def apply_summary
      username = get_item('cli::local_priv_user').value
      warning_message_brief = "'#{username}' access configuration requires manual verification"
      if @applied_status == :deferred
         extra = ":\n    #{warning_message_brief}"
      else
        extra = ''
      end
      "'#{username}' access verification after `simp bootstrap` #{@applied_status}" + extra
    end
  end
end
