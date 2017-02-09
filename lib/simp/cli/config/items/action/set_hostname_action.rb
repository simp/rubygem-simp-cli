require File.expand_path( '../action_item', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::SetHostnameAction < ActionItem
    def initialize
      super
      @key               = 'hostname::conf'
      @description       = 'Set hostname'
      @die_on_apply_fail = true
      @fqdn              = nil
    end

    def apply
      @applied_status = :failed

      @fqdn     = get_item( 'cli::network::hostname' ).value
      # TODO: should we use this shortname instead of fqdn?
      hostname = @fqdn.split('.').first

      # copy/pasta'd logic from old simp config
      # TODO: replace this with 'puppet apply' + network::global
      debug( 'Updating hostname' )

      success = execute("hostname #{@fqdn}")

      debug( 'Updating /etc/sysconfig/network' )
      if (success)
        # only sed error is if file does not exist
        success = success && execute("sed -i '/HOSTNAME/d' /etc/sysconfig/network")
      end

      if (success)
        success = success && execute("echo HOSTNAME=#{@fqdn} >> /etc/sysconfig/network")
      end

      # For EL 7 / systemd
      if success && File.exist?('/etc/hostname')
        debug( 'Updating /etc/hostname' )
        begin
          File.open('/etc/hostname','w'){|fh| fh.puts(@fqdn)}
        rescue Errno::EACCES
          success = false
        end

        if success
          # hostnamectl is required to persist the change under systemd
          success = success && execute("hostnamectl --static --pretty set-hostname #{@fqdn}")
        end
      end

      @applied_status = :succeeded if (success)
    end

    def apply_summary
      "Setting of hostname#{@fqdn ? ' to ' + @fqdn : ''} #{@applied_status}"
    end
  end
end
