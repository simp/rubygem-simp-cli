require File.expand_path( '../../../defaults', File.dirname(__FILE__) )
require File.expand_path( '../action_item', File.dirname(__FILE__) )
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::CheckRemoteYumConfigAction < ActionItem
    attr_accessor :warning_file
    attr_reader :warning_message

    def initialize
      super
      @key             = 'yum::repositories::remote::check'
      @description     = 'Check remote YUM configuration'
      @warning_file    = Simp::Cli::BOOTSTRAP_START_LOCK_FILE 
      @warning_message_brief = 'Locking bootstrap due to possibly incomplete YUM config'
      @warning_message = <<DOC
When the SIMP server is installed from ISO, it is configured via
/etc/yum.repos.d/simp_filesystem.repo and simp::yum class parameters
to use local system (OS) and local SIMP repositories in /var/www/yum.
Since /etc/yum.repos.d/simp_filesystem.repo does not exist on this
system, you must manually set up your system and SIMP repositories and
then set SIMP server configuration appropriately.  This must be done
prior to 'simp bootstrap', or the boostrap will fail.

Once you have successfully configured YUM and verified that
'repoquery -i kernel' returns the correct OS repository and
'repoquery -i simp' returns the correct SIMP repository, you can 
remove this file.
DOC
   end

    def apply
      @applied_status = :failed

      # If repoquery returns nothing, a repo is definitely not set up.
      # If it returns something, we are going to ASSUME the repo is set
      # up, but we have no way to verify that the listed repository
      # is the intended repository.
      result = execute('repoquery -i kernel | grep ^Repository')
      result = result && execute('repoquery -i simp | grep ^Repository')

      if result
        @applied_status = :succeeded
      else
        # issue a warning
        warn( "\nWARNING: #{@warning_message_brief}", [:YELLOW] )

        # create file that will prevent bootstrap from running until problem
        # is fixed
        FileUtils.mkdir_p(File.expand_path(File.dirname(@warning_file)))
        File.open(@warning_file, 'w') do |file|
          file.write @warning_message
        end
        @applied_status = :failed
      end
    end

    def apply_summary
      if @applied_status == :failed
      %Q{Your YUM configuration may be incomplete.  Verify you have set up system (OS)
    updates and SIMP repositories before running 'simp bootstrap'.}
      else
        "Checking remote YUM configuration #{@applied_status}"
      end
    end
  end
end
