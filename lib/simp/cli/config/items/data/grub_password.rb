require_relative '../password_item'

module Simp; end
class Simp::Cli; end


module Simp::Cli::Config
  class Item::GrubPassword < PasswordItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key           = 'grub::password'
      @description   = <<~EOM.strip
        The password to access GRUB.

        The value entered is used to set the GRUB password and to generate a hash
        stored in #{@key}.
      EOM
      @password_name = 'GRUB'
    end

    def query_prompt
      # make it clear we are asking for the password, not the hash
      'GRUB password'
    end

    def validate string
      if @value.nil?
        # we should be dealing with an unencrypted password
        !string.to_s.strip.empty? && super
      else
        # the password hash has been pre-assigned
        # TODO need something better
        (string =~ /^(grub\.pbkdf2.*)/) # grub2
      end
    end


    def encrypt string
      `grub2-mkpasswd-pbkdf2 <<EOM\n#{string}\n#{string}\nEOM`.split.last
    end
  end
end
