require File.expand_path( '../../../defaults', File.dirname(__FILE__) )
require File.expand_path( '../action_item', File.dirname(__FILE__) )
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::WarnLockoutRiskAction < ActionItem
    attr_accessor :warning_file
    attr_reader :warning_message

    def initialize
      super
      @key             = 'login::lockout::check'
      @description     = 'Check for login lockout risk'
      @warning_file    = Simp::Cli::BOOTSTRAP_START_LOCK_FILE
      @warning_message_brief = 'Locking bootstrap due to potential login lockout.'
      @warning_message = <<DOC

#{'#'*72}
Per security policy, SIMP, by default, disables login via ssh for all
users, including 'root', and beginning with SIMP 6.0.0 (when
useradd::securetty is empty), disables root logins at the console.  So,
to prevent lockout in systems for which no administrative user account
has yet been created or both console access is not available and the
administrative user's ssh access has not yet been enabled, you should
configure a local user for this server to have both su and ssh
privileges.  This entails the following:

1. Create a local user account, as needed, using useradd.

2. Create a Puppet manifest to enable su and allow ssh access.  For
   example,

   class userx_user (
   Boolean $pam = simplib::lookup('simp_options::pam', { 'default_value' => false }),
   ) {
     if $pam {
       include '::pam'

       pam::access::rule { 'allow_userx':
         users   => ['userx'],
         origins => ['ALL'],
         comment => 'The local user, used to remotely login to the system in the case of a lockout.'
       }
     }

     sudo::user_specification { 'default_userx':
       user_list => ['userx'],
       runas     => 'root',
       cmnd      => ['/bin/su root', '/bin/su - root']
     }
   }

3. Add the class created in Step 2 to the class list for the SIMP
   server in its host YAML file.

      ...
      classes:
        - userx_user
      ...

4. If the local user is configured to login with pre-shared keys
   instead of a password, copy the authorized_keys file for that
   user to /etc/ssh/local_keys/<username>.  For example,

   cp ~userx/.ssh/authorized_keys /etc/ssh/local_keys/userx

Once you have configured a user with both su and ssh privileges and
addressed any other issues identified in this file, you can remove
this file and continue with 'simp bootstrap'.
DOC
    end

    def apply
      warn( "\nWARNING: #{@warning_message_brief}", [:RED] )
      warn( "See #{@warning_file} for details", [:RED] )

      # append/create file that will prevent bootstrap from running until problem
      # is fixed
      FileUtils.mkdir_p(File.expand_path(File.dirname(@warning_file)))
      File.open(@warning_file, 'a') do |file|
          file.write @warning_message
      end
      @applied_status = :failed
    end

    def apply_summary
      if @applied_status == :failed
        "'simp bootstrap' has been locked due to potential login lockout.\n  * See #{@warning_file} for details"
      else
        "Check for login lockout risk #{@applied_status}"
      end
    end
  end
end
