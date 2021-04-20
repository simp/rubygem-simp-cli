require_relative '../action_item'
require_relative '../data/cli_local_priv_user'
require 'etc'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CopySshAuthorizedKeysAction < ActionItem
    attr_accessor :dest_dir

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key               = 'copy::ssh_authorized_keys'
      @description       = 'Copy local privileged user ssh authorized keys to managed dir'
      @category          = :system
      @die_on_apply_fail = true
      @dest_dir          = '/etc/ssh/local_keys'
      @username          = nil
    end

    def apply
      @applied_status = :failed
      @username = get_item( 'cli::local_priv_user' ).value

      info = nil
      begin
        info = Etc.getpwnam(@username)
      rescue ArgumentError => e
        err_msg = "Copy of ssh authorized keys for '#{@username}' failed:\n"
        err_msg += "  Local user '#{@username}' does not exist"
        error(err_msg)
      end

      if info
        authorized_keys_file = File.join(info.dir, '.ssh', 'authorized_keys')
        if File.exist?(authorized_keys_file)
          dest = "#{@dest_dir}/#{@username}"
          info( "Copying ssh authorized keys for '#{@username}' to SIMP-managed #{dest}" )
          begin
            # dest directory may not exist yet
            FileUtils.mkdir_p(dest_dir)
            FileUtils.chmod(0755, dest_dir)
            FileUtils.cp(authorized_keys_file, dest)
            FileUtils.chmod(0644, dest)
            @applied_status = :succeeded
            @applied_detail = "After bootstrap, the ssh authorized keys file for '#{@username}' is #{dest}"
          rescue Exception => e
            error("Copy of #{authorized_keys_file} to #{dest} failed:\n#{e}")
          end
        else
          info("#{authorized_keys_file} does not exist")
          @applied_status = :unnecessary
        end
      end
    end

    def apply_summary
      "Copy of user#{@username ? " '#{@username}'" : ''} ssh authorized keys to #{@dest_dir}/ #{@applied_status}" +
        (@applied_detail ? ":\n    #{@applied_detail}" : '')
    end
  end
end
