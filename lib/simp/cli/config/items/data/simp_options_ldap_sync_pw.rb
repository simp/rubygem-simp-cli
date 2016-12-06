require File.expand_path( '../password_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapSyncPw < PasswordItem
    def initialize
      super
      @key           = 'simp_options::ldap::sync_pw'
      @description   = %Q{The LDAP Sync password.}
      @data_type     = :server_hiera
      @password_name = 'LDAP Sync'
    end

    def query_prompt
      'LDAP Sync password'
    end

    def validate string
      !string.to_s.strip.empty? && super
    end


    # LDAP Bind PW must known and stored in cleartext
    def encrypt string
      string
    end
  end
end
