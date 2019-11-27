require_relative '../../../defaults'
require_relative '../action_item'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CheckServerYumConfigAction < ActionItem
    attr_accessor :warning_file
    attr_reader :warning_message

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key             = 'yum::repositories::server::config::check'
      @description     = 'Check YUM configuration for SIMP server'
      @category        = :sanity_check
      @warning_file    = Simp::Cli::BOOTSTRAP_START_LOCK_FILE
      @warning_message_brief = 'Locking bootstrap due to possibly incomplete YUM config'
      @warning_message = <<DOC
#{'#'*72}
When the SIMP server is installed from ISO, it is configured via
/etc/yum.repos.d/simp_filesystem.repo and simp::yum class parameters
to use local system (OS) and local SIMP repositories in /var/www/yum.
Since /etc/yum.repos.d/simp_filesystem.repo does not exist on this
system, you must manually set up your system and SIMP repositories and
then set SIMP server configuration appropriately.  This must be done
prior to 'simp bootstrap', or the boostrap will fail.

Once you have successfully configured YUM and verified that
  1. 'repoquery -i kernel' returns the correct OS repository
  2. 'repoquery -i simp' returns the correct SIMP repository
  3. 'repoquery -i puppet-agent' returns the correct SIMP
     dependencies repository
  4. Any other issues identified in this file are addressed,
you can remove this file and continue with 'simp bootstrap'.
DOC
   end

    def apply
      @applied_status = :failed

      # If repoquery returns nothing, a repo is definitely not set up.
      # If it returns something, we are going to ASSUME the repo is set
      # up, but we have no way to verify that the listed repository
      # is the intended repository.
      result = Simp::Cli::Utils::show_wait_spinner {
        query_result = true
        ['kernel', 'simp', 'puppet-agent'].each do |pkg|
          query = run_command("repoquery -i #{pkg}")[:stdout].strip
          query_result = false if not query =~ /^Repository/
        end
        query_result
      }

      if result
        @applied_status = :succeeded
      else
        # issue a warning
        warn( "\nWARNING: #{@warning_message_brief}", [:RED] )
        warn( "See #{Simp::Cli::BOOTSTRAP_START_LOCK_FILE} for details", [:RED] )

        # append/create file that will prevent bootstrap from running until
        # problem is fixed
        FileUtils.mkdir_p(File.expand_path(File.dirname(@warning_file)))
        File.open(@warning_file, 'a') do |file|
          file.write @warning_message
        end
        @applied_status = :failed
      end
    end

    def apply_summary
      if @applied_status == :failed
      %Q{Your SIMP server's YUM configuration may be incomplete.  Verify you have set up
\tOS updates, SIMP and SIMP dependencies repositories before running
\t'simp bootstrap'.}
      else
        "Checking of SIMP server's YUM configuration #{@applied_status}"
      end
    end
  end
end
