require File.expand_path( '../action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end

# NOTE:
# * EL used GRUB 0.9 up through EL6. EL7 moved to Grub 2.0.
# * The two versions of GRUB use completely different configurations
#   (files, encryption commands, etc).
# * The augeasproviders_grub Puppet module does not have a GRUB 0.9 provider for
#   the grub_user resource.  So, we don't have a uniform way of setting the
#   password using Puppet.
#
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
        result = set_password_grub(grub_hash)
      else
        result = set_password_old_grub(grub_hash)
      end
      @applied_status = :succeeded if result
    end

    def apply_summary
      "Setting of GRUB password #{@applied_status}"
    end

    def set_password_grub(grub_hash)
      grub_users = '/etc/grub.d/01_users'

      if File.exist?(grub_users)
        result = execute("sed -i 's/password_pbkdf2 root.*$/password_pbkdf2 root #{grub_hash}/' #{grub_users}'")
      else
        result = execute("echo 'password_pbkdf2 root #{grub_hash}' > #{grub_users}")
        FileUtils.chmod(0755, grub_users)
      end

      result && execute("grub2-mkconfig -o /etc/grub2.cfg")
    end

    def set_password_old_grub(grub_hash)
      if File.exist?('/boot/grub/grub.conf')
        # BIOS boot
        grub_conf = '/boot/grub/grub.conf'
      elsif File.exist?('/boot/efi/EFI/redhat/grub.conf')
        # EFI boot
        grub_conf = '/boot/efi/EFI/redhat/grub.conf'
      end
      if grub_conf
        result = execute("sed -i '/password/ c\password --encrypted #{grub_hash}' #{grub_conf}")
      else
        raise('Could not find grub.conf:  Expected /boot/grub/grub.conf or /boot/efi/EFI/redhat/grub.conf')
      end
    end
  end
end
