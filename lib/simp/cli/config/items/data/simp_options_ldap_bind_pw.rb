require_relative '../password_item'

module Simp; end
class Simp::Cli; end

module Simp::Cli::Config
  class Item::SimpOptionsLdapBindPw < PasswordItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
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
