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
      @key            = 'set_grub_password_action'
      @description    = 'Set GRUB password'
      @applied_status = :unattempted
    end

    def apply
      @applied_status = :failed
      grub_hash  = get_item('grub::password').value
      os_name    = Facter.value('os')['name'].downcase
      os_ver     = Facter.value('os')['release']['major']
      efi        = File.exist?('/sys/firmware/efi')
      grub_dir   = 'none'
      if os_ver > "6"
        if efi
          grub_dir = "/boot/efi/EFI/#{os_name}"
        else
          grub_dir = "/boot/grub2"
        end
        grub_file = "grub.cfg"
      else
        if efi
          grub_dir = "/boot/efi/EFI/#{os_name}"
        else
          grub_dir = "/boot/grub"
        end
        grub_file = "grub.conf"
      end
      if File.exist?("#{grub_dir}/#{grub_file}")
        if os_ver > "6"
          result = set_password_grub(grub_hash,grub_dir)
        else
          result = set_password_old_grub(grub_hash,"#{grub_dir}/#{grub_file}")
        end
        @applied_status = :succeeded if result
      else
        err_msg = "Could not find grub config file:  Expected #{grub_dir}/#{grub_file}"
        raise ApplyError.new(err_msg)
      end
    end

    def apply_summary
      "Setting of GRUB password #{@applied_status}"
    end

    def set_password_grub(grub_hash,grub_dir)
      begin
        result =  File.write("#{grub_dir}/user.cfg","GRUB2_PASSWORD=#{grub_hash}")
      rescue Errno::EACCES
        result = false
      end
      result && execute("grub2-mkconfig -o #{grub_dir}/grub.cfg")
    end

    def set_password_old_grub(grub_hash,grub_conf)
      result = execute("sed -i '/password/ c\password --encrypted #{grub_hash}' #{grub_conf}")
    end
  end
end
