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

This remainder of this document provides instructions on creating a local user
that has the appropriate level of system access.

-------------------------------
Configure Local User for Access
-------------------------------

This example creates a `local_system_access` Puppet module in the `production`
Puppet environment.

* IF YOU ALREADY HAVE AN UNPRIVILEGED ACCOUNT:

   * Replace `userx` with your current NON-ROOT username throughout the
     example code.

* IF YOU DO not ALREADY HAVE AN UNPRIVILEGED ACCOUNT:

   * Create a local user account, using `useradd`.

     * This example assumes the local user is named `userx`.
     * Be sure to set the user's password if the user is logging in with a
       password!

1. Run `sudo su - root`

2. Set your `umask`.

   +-------------+
   | $ umask 022 |
   +-------------+

3. Create a `local_system_access` puppet module directory and change to the
   directory.

   +-----------------------------------------------------------+
   | $ cd /etc/puppetlabs/code/environments/production/modules |
   | $ mkdir -p local_system_access/manifests                  |
   | $ cd local_system_access                                  |
   +-----------------------------------------------------------+

4. Add the following to a new `manifests/local_user.pp` file to enable `sudo su - root`
   and allow `ssh` access for the user you created/selected:

     class local_system_access::local_user (
       Boolean $pam = simplib::lookup('simp_options::pam', { 'default_value' => false }),
     ) {

       sudo::user_specification { 'default_userx':
         user_list => ['userx'],
         runas     => 'root',
         # ONLY NEEDED IF YOUR USER DOES NOT USE A PASSWORD
         passwd    => false,
         cmnd      => ['/bin/su root', '/bin/su - root']
       }

       if $pam {
         include 'pam'

         pam::access::rule { 'allow_userx':
           users   => ['userx'],
           origins => ['ALL'],
           comment => 'Local user for lockout prevention'
         }
       }
     }

5. Add the following to a new `metadata.json` file to enable proper
   recognition of your module by the puppet server:

     {
       "name": "local_system_access",
       "version": "0.0.1",
       "author": "Your name or group here",
       "summary": "Configures Local User for sudo access",
       "license": "Apache-2.0",
       "source": "Your gitlab url or local",
       "dependencies": [
         {
           "name": "simp/pam"
         },
         {
           "name": "simp/simplib"
         },
         {
           "name": "simp/sudo"
         }
       ]
     }

6. Make sure the permissions are correct on the module:

   +-----------------------------+
   | $ chown -R root:puppet $PWD |
   | $ chmod -R g+rX $PWD        |
   +-----------------------------+

7. Add the module to the SIMP server's host YAML file class list:

   +--------------------------------------------------------------+
   | $ cd /etc/puppetlabs/code/environments/production/data/hosts |
   +--------------------------------------------------------------+

   Add `local_system_access::local_user` to the `simp::classes:` array
   in `<SIMP server FQDN>.yaml`

     simp::classes:
       - local_system_access::local_user
       # Do NOT remove other items in this array
       # Make sure your whitespace lines up (spaces, not tabs)

8. Add the `local_system_access` module to the `Puppetfile` in the `production`
   environment:

   Edit `/etc/puppetlabs/code/environments/production/Puppetfile`,
   and add the following line under the section that says
   "Add your own Puppet modules here"

     mod 'local_system_access', :local => true


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
