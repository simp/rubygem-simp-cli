require File.expand_path( '../set_server_hieradata_action_item', __dir__ )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DisallowSimpUserAction < SetServerHieradataActionItem
    attr_accessor :host_dir

    def initialize
      @hiera_to_add = [
        'simp::server::allow_simp_user'
      ]
      super
      @key            = 'disallow::simp::server'

      # override with a shorter message
      @description    = "Disallow inapplicable 'simp' user in SIMP server <host>.yaml"
    end

    # override with a better message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Disallow of inapplicable, local 'simp' user in #{file} #{@applied_status}"
    end
  end
end
