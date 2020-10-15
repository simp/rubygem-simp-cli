require_relative '../../../defaults'
require_relative '../action_item'
require 'fileutils'

module Simp; end
class Simp::Cli; end
module Simp::Cli::Config
  class Item::WarnLockoutRiskAction < ActionItem
    attr_accessor :warning_file
    attr_reader :warning_message

    def initialize(puppet_env_info = DEFAULT_PUPPET_ENV_INFO)
      super(puppet_env_info)
      @key             = 'login::lockout::check'
      @description     = 'Check for login lockout risk'
      @category        = :sanity_check
      @warning_file    = Simp::Cli::BOOTSTRAP_START_LOCK_FILE
      @warning_message_brief = 'Locking bootstrap due to potential login lockout.'
      @warning_message = <<DOC

#{'#'*72}
By default, SIMP:

  * Disables remote logins for all users.
  * Disables `root` logins at the console.

If one of the following scenarios applies, you MUST enable `sudo` and `ssh`
access for a local user. If you do not do this, you may lose access to your
system.

SCENARIO 1:

  Console access is available, but not allowed, for `root` and no other user
  account is available.

    * This generally occurs when SIMP is installed from RPM and the user
      accepts `simp config`'s default value for `useradd:securetty`
      (an empty array).

SCENARIO 2:

  Console access is not available and the administrative user's `ssh`
  access has not yet been enabled permanently via Puppet.

    * This generally occurs when SIMP is installed from RPM on cloud systems.

In either of these scenarios, `simp config` will create this lock file which
prevents `simp bootstrap` from progressing.

This remainder of this document provides instructions on ensuring that a local
user has the appropriate level of system access.

--------------------------
Ensuring Local User Access
--------------------------

* IF YOU ALREADY HAVE AN UNPRIVILEGED ACCOUNT:

   * Replace `userx` with your current NON-ROOT username throughout the
     example code.

* IF YOU DO not ALREADY HAVE AN UNPRIVILEGED ACCOUNT:

   * Create a local user account, using `useradd`.

     * This example assumes the local user is named `userx`.
     * Be sure to set the user's password if the user is logging in with a
       password!

1. Run `sudo su - root`

2. Run ``cd /etc/puppetlabs/code/environments/production/data``

3. Add the following to ``default.yaml``

# Add sudo user rules
sudo::user_specifications:
  # Any unique name
  userx_su:
    # The users to which to apply this sudo rule
    user_list:
      - userx
    # The commands that the user is allowed to run
    cmnd:
      - ALL
    # Whether or not the user must use a password
    passwd: false
# Add a PAM remote access rule
pam::access::users:
  # The user to add
  userx:
    # Allow access from everywhere
    origins:
      - ALL

-----------------------------------------
If Your Local User Uses an SSH Public Key
-----------------------------------------

* If the local user has an SSH public key available, copy the `authorized_keys`
  file for that user to the SIMP-managed location for authorized keys
  `/etc/ssh/local_keys` as shown below:

  +------------------------------------------------------------+
  | $ mkdir -p /etc/ssh/local_keys                             |
  | $ chmod 755 /etc/ssh/local_keys                            |
  | $ cp ~userx/.ssh/authorized_keys /etc/ssh/local_keys/userx |
  | $ chmod 644 /etc/ssh/local_keys/userx                      |
  +------------------------------------------------------------+

----------
Next Steps
----------

DO NOT REBOOT BEFORE VERIFYING USER ACCESS
USING AN ALTERNATE TERMINAL OR SSH SESSION

If any other issues are identified in `/root/.simp/simp_bootstrap_start_lock`,
you must address them before removing the file.

1. Remove the lock file and bootstrap the system

   +--------------------------------------------+
   | $ rm /root/.simp/simp_bootstrap_start_lock |
   | $ simp bootstrap                           |
   | $ puppet agent -t                          |
   +--------------------------------------------+

   The following items are not failures and can be ignored. All other errors or
   warnings should be addressed prior to proceeding:

     * Reboot notifications.
     * Warning/errors related to modules that manage services you have not
       completely set up, such as `named`.
     * `svckill` warnings regarding services found that would be killed if
       `svckill::mode` was set to `enforcing`.

2. Verify user accesss

   * Using a NEW SSH SESSION OR TERMINAL (do NOT close your working session)

     * Log in as `userx`
     * `sudo su - root`

+----------------------------------------------------------------+
| If your new user cannot ssh into the server and sudo to `root` |
|                                                                |
| * DO NOT reboot the server until you resolve the problem!      |
|                                                                |
| * DO NOT log out of your primary work terminal                 |
|   until you resolve the problem!                               |
+----------------------------------------------------------------+
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
