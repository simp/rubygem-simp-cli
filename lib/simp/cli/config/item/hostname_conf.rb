require 'highline/import'
require File.expand_path( '../item', File.dirname(__FILE__) )
require File.expand_path( '../utils', File.dirname(__FILE__) )

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::HostnameConf < ActionItem
    def initialize
      super
      @key               = 'hostname::conf'
      @description       = 'Configures hostname; action-only.'
      @die_on_apply_fail = true
      @fqdn              = nil
    end

    def apply
      @applied_status == :failed

      success  = true
      @fqdn     = @config_items.fetch( 'hostname'    ).value
      # TODO: should we use this shortname instead of fqdn?
      hostname = @fqdn.split('.').first

      # copy/pasta'd logic from old simp config
      # TODO: replace this with 'puppet apply' + network::global
      say_green '  updating hostname...' if !@silent

      `hostname #{@fqdn}`
      success = success && $?.success?

      `sed -i '/HOSTNAME/d' /etc/sysconfig/network`
      success = success && $?.success? #only error is if file does not exist

      `echo HOSTNAME=#{@fqdn} >> /etc/sysconfig/network`
      success = success && $?.success?

      # For EL 7 / systemd
      if File.exist?('/etc/hostname')
        say_green '  updating /etc/hostname...'
        File.open('/etc/hostname','w'){|fh| fh.puts(@fqdn)}

        # hostnamectl is required to persist the change under systemd
        `hostnamectl --static --pretty set-hostname #{@fqdn}`
        success = success && $?.success?
      end

      @applied_status = :succeeded if (success)
    end

    def apply_summary
      "Setting of hostname#{@fqdn ? ' to ' + @fqdn : ''} #{@applied_status}"
    end
  end
end
