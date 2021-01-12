require_relative '../action_item'
require_relative '../data/grub_password'

module Simp; end
class Simp::Cli; end

# NOTE:
# * EL used GRUB 0.9 up through EL6. EL7 moved to Grub 2.0.
# * The two versions of GRUB use completely different configurations
#   (files, encryption commands, etc).
# * The augeasproviders_grub Puppet module does not have a GRUB 0.9 provider for
#   the grub_user resource.  So, we don't have a uniform way of setting the
#   password using Puppet.
#
module Simp::Cli::Config
  class Item::SetGrubPasswordAction < ActionItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key            = 'set_grub_password_action'
      @description    = 'Set GRUB password'
      @category       = :system
      @applied_status = :unattempted
    end

    def apply
      @applied_status = :failed
      grub_hash = get_item('grub::password').value
      result = set_password_grub(grub_hash)
      @applied_status = :succeeded if result
    end

    def apply_summary
      "Setting of GRUB password #{@applied_status}"
    end

    # This requires augeasproviders_grub 3.0.1 or later.  There were errors in the
    # provider before this time that did not create the file in /etc/grub.d correctly.
    def set_password_grub(grub_hash)
      cmd = %Q(#{@puppet_apply_cmd} -e "grub_user { 'root': password => '#{grub_hash}', superuser => true }")
      result = execute(cmd)
    end

  end
end
