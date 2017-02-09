require File.expand_path( '../set_server_hieradata_action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::EnableOsAndSimpYumReposAction < SetServerHieradataActionItem
    attr_accessor :host_dir

    def initialize
      @hiera_to_add = [
        'simp::yum::enable_os_repos',
        'simp::yum::enable_simp_repos'
      ]
      super
      @key            = 'yum::repositories::enable'

      # override with a shorter message
      @description    = 'Enable remote YUM repos in SIMP server <host>.yaml'
    end

    # override with a better message
    def apply_summary
      file = @file ? File.basename(@file) : 'SIMP server <host>.yaml'
      "Enabling of remote system (OS) and SIMP YUM repositories in #{file} #{@applied_status}"
    end
  end
end
