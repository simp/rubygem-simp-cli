require_relative '../set_server_hieradata_action_item'
require_relative '../data/simp_grub_password'
require_relative '../data/simp_grub_admin'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SetServerGrubConfigAction < SetServerHieradataActionItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      @hiera_to_add = [ 'simp_grub::password', 'simp_grub::admin' ]
      super(puppet_env_info)
      @key = 'puppet::set_server_grub_config'

      # override with a shorter message
      @description = 'Set GRUB password hash in SIMP server <host>.yaml'
    end

    # override with a shorter message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Setting of GRUB password hash in #{file} #{@applied_status}"
    end
  end
end
