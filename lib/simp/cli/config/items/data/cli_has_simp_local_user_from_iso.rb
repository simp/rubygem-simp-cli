require_relative '../yes_no_item'
require 'etc'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CliHasSimpLocalUserFromIso < YesNoItem
    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key         = 'cli::has_simp_local_user_from_iso'
      @description = <<~EOM.strip
        Whether the server has the local 'simp' user created by
        an ISO install.

        Per security policy, SIMP, by default, disables login via ssh for all
        users, including 'root', and beginning with SIMP 6.0.0 disables, root
        logins at the console.  So, to prevent lockout in systems for which
        no administrative user account has yet been created or both console
        access is not available and the administrative user's ssh access
        has not yet been enabled, the SIMP ISO installation creates a
        local user, 'simp', for which su and ssh privileges will be enabled
        via the simp::server manifest, when SIMP is bootstrapped.
      EOM
      @data_type  = :internal  # don't persist this as it needs to be
                               # evaluated each time simp config is run
      @username = 'simp'

      # FIXME This is especially fragile....ASSuming ISO install because a
      # file installed by the ISO (and unfortunately, a file that should be,
      # but, as of now, is not managed by SIMP) exists.
      @iso_marker = '/etc/yum.repos.d/simp_filesystem.repo'
    end

    def iso_install?
      File.exist?(@iso_marker)
    end

    def get_os_value
      begin
        Etc.getpwnam(@username)

        # just to be sure this user is from an ISO install
        if iso_install?
          return 'yes'
        else
          return 'no'
        end
      rescue ArgumentError => e
        return 'no'
      end
    end

    def get_recommended_value
      os_value
    end
  end
end
