require_relative '../action_item'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::WarnClientYumConfigAction < ActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key             = 'yum::repositories::client::config::check'
      @description     = 'Check YUM configuration for SIMP clients'
      @category        = :sanity_check
      @warning_message = <<DOC
Unable to verify YUM configuration for SIMP clients.  Please
manually verify prior to kickstarting SIMP clients.

See https://docs.puppet.com/puppet/latest/types/yumrepo.html for
a description of the Puppet native type for YUM repositories.
DOC

      @warning_message_brief = 'Your SIMP client YUM configuration requires manual verification'
   end

    def apply
      @applied_status = :deferred
      warn( "\nWARNING: #{@warning_message.strip}", [:YELLOW] )
      pause(:warn)
    end

    def apply_summary
      if @applied_status == :deferred
         extra = ":\n\t#{@warning_message_brief}"
      else
        extra = ''
      end
      "Checking YUM configuration for SIMP clients #{@applied_status}" + extra
    end
  end
end
