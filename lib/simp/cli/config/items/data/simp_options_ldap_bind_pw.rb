require File.expand_path( '../password_item',  __dir__ )

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapBindPw < PasswordItem
    def initialize
      super
      @key           = 'simp_options::ldap::bind_pw'
      @description   = %Q{The LDAP Bind password.}
      @password_name = 'LDAP Bind'
    end

    def query_prompt
      'LDAP Bind password'
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
