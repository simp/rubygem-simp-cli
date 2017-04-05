require File.expand_path( '../set_server_hieradata_action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::DisableServerLocalOsAndSimpYumReposAction < SetServerHieradataActionItem
    attr_accessor :host_dir

    def initialize
      @hiera_to_add = [
        'simp::yum::repo::local_os_updates::enable_repo',
        'simp::yum::repo::local_simp::enable_repo'
      ]
      super
      @key            = 'yum::repositories::local::disable'

      # override with a shorter message
      @description    = 'Disable duplicate YUM repos in SIMP server <host>.yaml'
    end

    # override with a better message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Disabling of duplicate OS and SIMP YUM repositories in #{file} #{@applied_status}"
    end
  end
end
