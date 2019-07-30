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
Per security policy, SIMP, by default, disables login via `ssh` for all users,
including `root`, and beginning with SIMP 6.0.0, disables `root` logins at
the console by default.  So, if one of the following scenarios applies, you
should configure a local user for this server to have both `su` and `ssh`
privileges, in order to prevent `root` lockout from the system:

* Console access is available but not allowed for `root` and no other
  administrative user account has yet been created.

  * This can happen when SIMP is installed from RPM and the user accepts
    `simp config`'s default value for `useradd:securetty` (an empty array).

* Both console access is not available and the administrative user's `ssh`
  access has not yet been enabled (permanently) via Puppet.

  * This can happen when SIMP is installed from RPM on cloud systems.

If you have access to the console, have the `root` password, and have enabled
`root` console access by specifying an appropriate TTY when `simp config`
asked you about `useradd::securetty` (e.g., `tty0`), this warning is not
applicable.  If there are no other issues identified in this file, you can
simply remove it and run `simp bootstrap`.

Otherwise, to address the potential `root` lockout issue, follow the
instructions below.

Configure Local User for Access
-------------------------------

In these instructions, you will create a manifest in a local module, `mymodule`,
in the `production` Puppet environment.  Execute these operations as `root`.

 *  See https://puppet.com/docs/puppet/latest/modules.html for information on how
    to create a Puppet module.

1. Create a local user account, as needed, using `useradd`.  This example
   assumes the local user is `userx`.

   * Be sure to set the user's password if the user is logging in with a password.
   * SIMP is configured to create a home directory for the user, if it does
     not exist when the user first logs in.

2. Create a `local_user.pp` manifest in `mymodule/manifests` to enable
   `sudo su - root` and allow `ssh` access for the user you created/selected:

   a) Create the manifest directory

        $ mkdir -p /etc/puppetlabs/code/environments/production/modules/mymodule/manifests

   b) Create /etc/puppetlabs/code/environments/production/modules/mymodule/manifests/local_user.pp
      with the following content:

        class mymodule::local_user (
          Boolean $pam = simplib::lookup('simp_options::pam', { 'default_value' => false }),
        ) {

          sudo::user_specification { 'default_userx':
            user_list => ['userx'],
            runas     => 'root',
            cmnd      => ['/bin/su root', '/bin/su - root']
          }

         if $pam {
           include 'pam'

           pam::access::rule { 'allow_userx':
             users   => ['userx'],
             origins => ['ALL'],
             comment => 'The local user, used to remotely login to the system in the case of a lockout.'
           }
         }
       }

3. Make sure the permissions are correct on the module:

     $ sudo chown -R root:puppet /etc/puppetlabs/code/environments/production/modules/mymodule
     $ sudo chmod -R g+rX /etc/puppetlabs/code/environments/production/modules/mymodule

4. Add the module to the SIMP server's host YAML file class list:

   Edit the SIMP server's YAML file,
   `/etc/puppetlabs/code/environments/production/data/<SIMP server FQDN>.yaml`
   and add the `mymodule::local_user` to the `classes` array:

     classes:
       - mymodule::local_user

5. If the local user is configured to login with pre-shared keys instead of a
   password (typical cloud configuration), copy the `authorized_keys` file for
   that user to the SIMP-managed location for authorized keys `/etc/ssh/local_keys`:

     $ sudo mkdir -p /etc/ssh/local_keys
     $ sudo chmod 755 /etc/ssh/local_keys
     $ sudo cp ~userx/.ssh/authorized_keys /etc/ssh/local_keys/userx
     $ sudo chmod 644 /etc/ssh/local_keys/userx

6. Add the module to the `Puppetfile` in the `production` environment:

   Edit the `Puppetfile` used to deploy the modules,
   `/etc/puppetlabs/code/environments/production/Puppetfile`,  and add a line
   under the section that says "Add you own Puppet modules here"

     mod 'mymodule'; :local => true

Next Steps
----------

If `root` lockout is the only issue identified in this file, remove the file
and continue with `simp bootstrap`.  If not, address any remaining issues,
remove the file, and then run `simp bootstrap`.
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
