require_relative '../password_item'

module Simp; end
class Simp::Cli; end


module Simp::Cli::Config
  class Item::SimpGrubPassword < PasswordItem

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key           = 'simp_grub::password'
      @description   = <<~EOM.strip
        The password to access GRUB.

        The value entered is used to set the GRUB password and to generate a hash
        stored in #{@key}.
      EOM
      @password_name = 'GRUB'
      @data_type     = :server_hiera
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
        # The grub2 password hash has been pre-assigned.
        (string =~ /^(grub\.pbkdf2.*)/) ? true : false
      end
    end

    def encrypt string
      encrypt_exe = '/usr/bin/grub2-mkpasswd-pbkdf2'
      if File.exist?(encrypt_exe)
        `#{encrypt_exe} <<EOM\n#{string}\n#{string}\nEOM`.split.last
      else
        msg = "Failed to encrypt GRUB password: #{encrypt_exe} does not exist"
        raise Simp::Cli::ProcessingError, msg
      end
    end
  end
end
