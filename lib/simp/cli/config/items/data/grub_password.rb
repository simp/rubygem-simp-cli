require File.expand_path( '../password_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end


# NOTE: EL used GRUB 0.9 up through EL6. EL7 moved to Grub 2.0
# NOTE: The two versions of GRUB use completely different configurations (files, encryption commands, etc)
module Simp::Cli::Config
  class Item::GrubPassword < PasswordItem

    def initialize
      super
      @key            = 'grub::password'
      @description    = %Q{The password to access GRUB.

The value entered is used to set the GRUB password and to generate a hash
stored in #{@key}.}
      @password_name  = 'GRUB'
      @applied_status = :unattempted
    end

    def query_prompt
      # make it clear we are asking for the password, not the hash
      'GRUB password'
    end

    def validate string
      !string.to_s.strip.empty? && super
    end


    def encrypt string
      result   = nil
      password = string
      if Facter.value('os')['release']['major'] > "6"
        result = `grub2-mkpasswd-pbkdf2 <<EOM\n#{password}\n#{password}\nEOM`.split.last
      else
        require 'digest/sha2'
        salt   = rand(36**8).to_s(36)
        result = password.crypt("$6$" + salt)
      end
      result
    end
  end
end
