require File.expand_path( '../action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end


# NOTE: EL used GRUB 0.9 up through EL6. EL7 moved to Grub 2.0
# NOTE: The two versions of GRUB use completely different configurations (files, encryption commands, etc)
module Simp::Cli::Config
  class Item::SetGrubPasswordAction < ActionItem

    def initialize
      super
      @key         = 'set_grub_password_action'
      @description = 'Set GRUB password'
      @applied_status = :unattempted
    end

    def apply
      @applied_status = :failed
      grub_hash = get_item('grub::password').value
      if Facter.value('os')['release']['major'] > "6"
        # TODO: beg team hercules to make a augeas provider for grub2 passwords?
        result = execute("sed -i 's/password_pbkdf2 root.*$/password_pbkdf2 root #{grub_hash}/' /etc/grub.d/01_users")
        result = result && execute("grub2-mkconfig -o /etc/grub2.cfg")
      else
        result= execute("sed -i '/password/ c\password --encrypted #{grub_hash}' /boot/grub/grub.conf")
      end
      @applied_status = :succeeded if result
    end

    def apply_summary
      "Setting of GRUB password #{@applied_status}"
    end

  end
end
