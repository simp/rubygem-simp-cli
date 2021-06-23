%global gemname simp-cli

%global gemdir /usr/share/simp/ruby
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global cli_version 7.0.0
%global highline_version 2.0.3

# gem2ruby's method of installing gems into mocked build roots will blow up
# unless this line is present:
%define _unpackaged_files_terminate_build 0

Summary: a cli interface to configure/manage SIMP
Name: rubygem-%{gemname}
Version: %{cli_version}
Release: 1%{?dist}
Group: Development/Languages
License: Apache-2.0
URL: https://github.com/simp/rubygem-simp-cli
Source0: %{name}-%{cli_version}-%{release}.tar.gz
Source1: %{gemname}-%{cli_version}.gem
Requires: cracklib
Requires: createrepo
Requires: curl
Requires: diffutils
Requires: elinks
Requires: facter >= 3
Requires: git
Requires: grep
Requires: grub2-tools-minimal
Requires: hostname
Requires: iproute
Requires: libpwquality
Requires: net-tools
Requires: policycoreutils
Requires: procps-ng
Requires: pupmod-herculesteam-augeasproviders_grub >= 3.0.1
Requires: pupmod-simp-network >= 6.0.3
Requires: pupmod-simp-resolv >= 0.1.1
Requires: pupmod-simp-simplib >= 3.11.1
Requires: puppet >= 6
Requires: rsync
Requires: rubygem(%{gemname}-highline) >= %{highline_version}
Requires: sed
Requires: simp-adapter >= 1.0.1
Requires: simp-environment-skeleton >= 7.1.1
Requires: yum-utils

BuildRequires: ruby(rubygems)
BuildRequires: ruby
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{cli_version}

%description
simp-cli provides the 'simp' command to configure and manage SIMP.

%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires: %{name} = %{cli_version}-%{release}
BuildArch: noarch

%description doc
Documentation for %{name}

%package highline
Summary: A highline Gem for use with the SIMP CLI
Version: %{highline_version}
Release: 0
License: GPL-2.0
URL: https://github.com/JEG2/highline
Source11: highline-%{highline_version}.gem
BuildRequires: ruby(rubygems)
BuildRequires: ruby
BuildArch: noarch
Provides: rubygem(%{gemname}-highline) = %{highline_version}

%description highline
simp-cli-highline is required for the proper functionality of simp-cli

%prep
%setup -q

%build

%install
echo "======= %setup PWD: ${PWD}"
echo "======= %setup gemdir: %{gemdir}"

mkdir -p %{buildroot}/%{gemdir}
mkdir -p %{buildroot}/%{_bindir} # NOTE: this is needed for el7
gem install --local --install-dir %{buildroot}/%{gemdir} --force %{SOURCE1}

cd ext/gems/highline
if [ `which bundle 2>/dev/null` ]; then
  bundle install
fi
gem install --local --install-dir %{buildroot}/%{gemdir} --force %{SOURCE11}
cd -

cat <<EOM > %{buildroot}%{_bindir}/simp
#!/bin/bash

PATH=/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:\$PATH

%{geminstdir}/bin/simp \$@

EOM

%files
%defattr(0644, root, root, 0755)
%{geminstdir}
%attr(0755,-,-) %{geminstdir}/bin/simp
%attr(0755,-,-) %{_bindir}/simp
%exclude %{gemdir}/cache/%{gemname}-%{cli_version}.gem
%{gemdir}/specifications/%{gemname}-%{cli_version}.gemspec

%files highline
%defattr(0644, root, root, 0755)
%{gemdir}/gems/highline-%{highline_version}
%exclude %{gemdir}/cache/highline-%{highline_version}.gem
%{gemdir}/specifications/highline-%{highline_version}.gemspec

%files doc
%doc %{gemdir}/doc

%changelog
* Thu Jun 17 2021 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 7.0.0
- simp config changes:
  - The LOCAL sssd domain is no longer needed for sssd to start. The
    sssd::domains value is now only set if the SIMP server is the LDAP server.
* Tue May 25 2021 Liz Nemsick <lnemsick.simp@gmail.com> - 7.0.0
- simp CLI changes:
  - Dropped support for Puppet 5.
- simp config changes:
  - Updated LDAP configuration to use 389ds, when the SIMP server is the LDAP
    is on EL>7.
    - Configures the LDAP server to be the SIMP 389ds accounts instance
    - Configures the LDAP client to communicate with the 389ds server.
  - Added option to configure a local user with ssh and sudo privileges
    to prevent server lockout, when SIMP is not installed from ISO.
    - Especially important for cloud instances when the user does not have
      console access.
    - Specified local user will be created if not already present.
    - If the specified local user exists and has authorized ssh keys, the keys
      will be copied to /etc/ssh/local_keys/, the default location of local user
      ssh authorized key files in SIMP.
      IMPORTANT: Any future updates to a users's ssh authorized key list must
      be made to the user's file in /etc/ssh/local_keys/.
  - Moved the mechanism to set the SIMP server's grub password to Puppet.
    - The password is now set via simp_grub::password instead of
      grub::password.
  - Fixed a bug in which running `simp config` multiple times could result in
    multiple /etc/hosts entries for the puppetserver.

* Tue Feb 09 2021 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 7.0.0
- simp config changes:
  - Configure simp_options::ntp::servers instead of deprecated
    simp_options::ntpd::servers.
  - Set the NTP server defaults for ntpd and chronyd.
    simp_options::ntp::servers is intended to be the default NTP server
    settings for a SIMP system, regardless of whether it uses ntpd or
    chronyd. However, the chrony module does not use simp_options,
    because it is not a SIMP-maintained module. To work around this,
    `simp config` was updated to set chrony::servers to an alias of
    simp_options::ntp::servers in hieradata.
  - Check for both ntpd and chronyd settings when determining the OS defaults
    for simp_options::ntp::server, not just ntpd settings.

* Mon Jan 11 2021 Liz Nemsick <lnemsick.simp@gmail.com> - 7.0.0
- Remove support for EL6

* Thu Dec 10 2020 Chris Tessmer <chris.tessmer@onyxpoint.com> - 7.0.0
- Bumped .gemspec dependencies to mitigate CVE-2020-8130

* Thu Oct 15 2020 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.1.1
- Change the local user lockout warning to have simpler instructions

* Wed Oct 07 2020 Liz Nemsick <lnemsick.simp@gmail.com> - 6.1.0
- Updated SIMP internet repositories configured by 'simp config'
  - Now uses simp-project.com repositories via new
    ``simp::yum::repo::internet_simp`` class
  - The packagecloud repositories are no longer being updated.
- Added instructions to the local user lockout warning message in the
  bootstrap lock file:
  - Explain how to create a metadata.json file with the correct module
    dependencies for the sample Puppet code.
  - Tell the user to check that they can ssh into the server with the new
    user after bootstrap but before rebooting. This step is imperative to
    ensure that the user can also get through Puppet-managed
    authentication!
- Fixed the following:
  - Bug in which `simp config` did not allow DNS domains that did
    not include at least one '.'.  Domains are now validated
    per RFC 3696.
  - Typo in a simp cli message about applying FACLs.
  - Incorrect path for the location of the SIMP server hieradata file
    in the local user lockout warning message in the bootstrap lock file.
  - Missing instructions in the local user lockout warning message about
    adding `passwd => false` to `simp::user_specification` for users who
    log in without a password.

* Wed Sep 30 2020 Liz Nemsick <lnemsick.simp@gmail.com> - 6.0.3
- Fixed a bug where 'simp config' recommended the wrong SSSD domain,
  when the SIMP server was not the LDAP server.  It recommended the
  'Local' domain, when the appropriate SIMP-created domain with the
  'local' (EL6) or 'files' (EL7) provider is 'LOCAL'.

* Thu Sep 10 2020 Liz Nemsick <lnemsick.simp@gmail.com> - 6.0.2
- Fixed a typo in an error message emitted when 'simp config' cannot
  proceed because the environment to configure already exists.
- Fixed a bug in `simp environment new` in which the actual failure
  messages from a failed `setfacl --restore` execution are not logged.
- Updated HighLine from version 1.7.8 to 2.0.3.

* Tue Sep 01 2020 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 6.0.1
- In Rakefile check if task spec_standalone exists before trying to
  clear it

* Thu Aug 13 2020 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.0.0
- Allow users to set the SIMP_ENVIRONMENT environment variable to change the
  initial environment from 'production' to a custom value
- Fixed an issue where --dry-run would prompt the user to apply instead of
  simply skipping to the (skipped) action items and then writing the
  ~/.simp/simp_conf.yaml file
- Ensure that `simp config` uses the `simp::classes` parameter instead
  of `classes` by default
- Accept both `simp::classes` and `classes` as valid existing configurations

* Fri Jan 03 2020 Liz Nemsick <lnemsick.simp@gmail.com> - 6.0.0
- Added simp kv command family to allow users to manage and inspect
  entries in a simpkv key/value store
- simp passgen changes
  - Split into sub-commands for ease of use:
    - 'simp passgen envs': List environments that may have 'simplib::passgen'
      passwords
    - 'simp passgen list': List names of 'simplib::passgen' passwords
    - 'simp passgen remove': Remove 'simplib::passgen' passwords
    - 'simp passgen set': Set 'simplib::passgen' passwords
    - 'simp passgen show':  Show 'simplib::passgen' passwords and other
      stored attributes
  - Updated to work with simpkv-enabled simplib::passgen.  Automatically
    detects whether simplib::passgen is operating in legacy mode or
    simpkv mode in the specified environment, and then executes password
    operations using the appropriate mechanism for that mode.
  - When setting passwords, disabled libpwquality/cracklib validation of
    user-entered passwords, by default, because not all passwords managed
    by simplib::passgen are user passwords.  This validation can be
    re-enabled with the '--validate' option of the 'simp passgen set' command.
  - Added the following command line options when creating passwords
    - '--[no-]auto-gen': Whether to auto-generate new passwords.
    - '--complexity': Password complexity to use when a password is
      auto-generated. Corresponds to the complexity option of simplib::passgen.
    - '--[no-]complex-only': Whether to only use only complex characters
      when a password is auto-generated. Corresponds to the complex_only
      option of simplib::passgen.
    - '--[no-]validate': Enabled validation of new passwords with
      libpwquality/cracklib.
    - '--length': Password length to use when a password is auto-generated.
  - Added '--[no-]details' option when showing password information.  When
    enabled, all available password information is displayed, not just the
    current and previous password values.
- simp config changes
  - Removed deprecated '--non-interactive' option.  Use '--force-defaults'
    instead.

* Fri Aug 30 2019 Trevor Vaughan <tvaughan@onyxpoint.com> - 6.0.0
- Fix Puppet Enterprise support

* Wed Aug 07 2019 Liz Nemsick <lnemsick.simp@gmail.com> - 5.0.3
- Fix errata in instructions on how to prevent possible root lockout
  from the SIMP server.

* Tue Jul 30 2019 Liz Nemsick <lnemsick.simp@gmail.com> - 5.0.2
- Flesh out incomplete instructions on how to prevent possible root
  lockout from the SIMP server.
- Fixed a typo in `simp environment new` built-in help.
- Fixed errata in `simp environment fix` built-in help.

* Thu Jul 11 2019 Michael Morrone <michael.morrone@onyxpoint.com> - 5.0.1
- Fixed a bug in which the tftpboot images copied into the rsync space in
  SIMP's secondary environment were not world readable.  This prevented
  clients from PXE booting.

* Tue Jun 11 2019 Chris Tessmer <chris.tessmer@onyxpoint.com> - 5.0.0
- Added 'simp environment' command
- Added `simp environment new` subcommand
- Added `simp environment fix` subcommand
- Added `simp puppetfile generate` command
  - `simp puppetfile` command
  - `simp puppetfile generate` sub-command
- Fixed various annoyances that prevented local smoke tests with `bin/simp`
  - Avoid using AIO Puppet with `USE_AIO_PUPPET=no`
  - Load all `simp` commands without `simp config` failing in non-puppetserver
    environments (`simp config` still fails as expected)
- Moved logger to `Simp::Cli::Logging`
- Fixed gem dependency-related warning when `simp` is run on real OSes
  - Updated dependency constraints in gemspec
  - Removed unnecessary ENV wrapper from gemspec
  - Documented changes in README.md

* Fri Jun 07 2019 Liz Nemsick <lnemsick.simp@gmail.com> - 5.0.0
- 'simp' change:
  - Standardized help mechanism to be -h at all levels
    (main, command, subcommand)
  - Added descriptions to top level help command list
- Added 'rsync' and 'git' to the RPM requires list.
- 'simp' change:
  - Fixed bug in which the wrong Facter environment variable was set
- 'simp config' changes:
  - Created a placeholder for where the OmniEnvController from the
    future 'simp environment' command would be used to set up the
    initial SIMP puppet and secondary environments.
  - Mock use of 'simp environment' code to set up the initial SIMP
    puppet and secondary environments.
  - Now require the user to use a new command line option,
    '--force-config', when the user wants to re-configure
    an existing SIMP puppet environment
  - Changed default environment from 'simp' (with corresponding
    'production' link) to 'production'
  - Restricted non-root user to only be able to run in '--dry-run'
    mode.  This was all that the user could actually do, but,
    without enforcement, lead to unexpected failures.
  - Fixed a bug in which the check for Puppet Enterprise was
    incorrect.  This resulted in incorrect puppetserver ports.
  - Reworked questionnaire to allow the user to opt out
    of LDAP all together
  - Removed code that loaded the scenario YAML files
  - Defer most actions until after all information has been
    gathered, instead of running them immediately.
    - When queries are appropriate, ask the user if they want to
      apply the configuration.
    - Group the deferred actions logically, so that the sequence
      of actions makes sense to the user.
  - Improved introductory text and descriptions of a few items
    that have been confusing for users
  - Removed the ability for a non-root user to set the Puppet
    digest algorithm.  This was a bug.
  - In cli::network::interface item, try to recommend an
    interface that has an IPv4 address set.  Also print out the
    list of available interfaces and their corresponding IPv4
    addresses (when set) in the description.
  - In cli::network::hostname item, when `hostname -A` returns
    more than one entry, iterate through all entries to try to
    find one that passes FQDN validation, instead of grabbing
    the first one.
  - Fail when the default, non-interactive value for a data item
    fails validation.
  - Added simp-cli version to the answers file as a YAML entry.
- 'simp bootstrap' changes:
    No longer checks for the 'simp' Puppet and secondary environments (with
    their corresponding 'production' links) and fails if they do not exist.
    Instead, checks for the existence of SIMP Puppet and secondary 'production'
    environments and fails if both are not present.
  - Checks validity of manifests in the 'production' environment,
    not 'simp' environment, as the link that made them
    equivalent is OBE.
  - Fixed a bug in which the check for Puppet Enterprise was
    incorrect.  This would result in Puppet FOSS-specific bootstrap
    operations being executed.
  - Added an additional puppet agent tagged run on the bootstrap port
  - Added more log messages to make bootstrap process more clear

* Wed Apr 03 2019 Jim Anderson <thesemicolons@protonmail.com> - 5.0.0
- Added message to bootstrap.rb indicating that puppetserver has been
  reconfigured to listen on a specific port. This message will be
  displayed if the port is changed to 8140, or if it remains on 8150.
- Fixed bug in which 'simp config' failed to find the template
  SIMP server host YAML file, puppet.your.domain.yaml, from
  /usr/share simp/environments/simp.  This bug caused subsequent
  'simp config' runs to fail, when the SIMP server hostname had
  changed from the hostname used in the first 'simp config' run.

* Mon Mar 18 2019 Trevor Vaughan <tvaughan@onyxpoint.com> - 5.0.0
- Ensure that a FQDN is used when running `simp config`
- Ensure that a FQDN is set when running `simp bootstrap`
- Fixed a bug where the web-routes.conf file was not being overwritten with a
  pristine copy. This meant that multiple calls to `simp bootstrap` would fail
  due to leftover CA entries in the file. The error provided is not clear and
  has been provided upstream to Puppet, Inc.
- Fixed a typo in an info block that would cause 'simp bootstrap' to fail if it
  had already been successfully run.

* Tue Jan 15 2019 Liz Nemsick <lnemsick.simp@gmail.com> - 4.4.0
- Added a `simp bootstrap` option to set the wait time for the
  puppetserver to start during the bootstrap process.

* Tue Jan 01 2019 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 4.3.2
- Fixed error in Changelog

* Tue Nov 27 2018 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 4.3.1
- Added missing dependencies to the rubygem-simp-cli.spec file

* Fri Oct 12 2018 Chris Tessmer <chris.tessmer@onyxpoint.com> - 4.3.0
- `simp config` removes the deprecated Puppet setting `trusted_server_facts`
- Add `:version` to `Simp::Cli::Utils.puppet_info`

* Tue Oct 09 2018 Chris Tessmer <chris.tessmer@onyxpoint.com> - 4.3.0
- Fixed `simp bootstrap` errors in puppetserver 5+:
  - No longer overwrites `web-routes.conf` (fixes fatal configuration error)
  - No longer adds `-XX:MaxPermSize` for Java >= 8 (fixes warnings at restart)

* Mon Oct 01 2018 Liz Nemsick <lnemsick.simp@gmail.com> - 4.3.0
- Update 'simp config' to support environment-specific Hiera 5
  configuration provided by SIMP-6.3.0.
  - Assumes a legacy Hiera 3 configuration, when the 'simp'
    environment only contains a 'hieradata' directory.
  - Assumes a Hiera 5 configuration configuration, when the 'simp'
    environment contains both a 'hiera.yaml' file and a 'data/'
    directory.
  - Fails to run otherwise, as neither stock SIMP configuration
    has been found and 'simp config' cannot safely modify
    hieradata.

* Sun Jul 15 2018 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.2.0
- Stripped trailing whitespace
- Adjusted bootstrap to detect PE and avoid operations that are detrimental to
  proper operation
- Made a few adjustments for overall safety
- Fixed dependency loading for 'highline/import' by clearing the gem cache

* Mon Apr 23 2018 Jeanne Greulich <jeanne.greulich@onyxpoint.com> - 4.1.0
- removed simp_options::selinux references in tests.
- update setting of grub2 password to use augeausproviders_grub.

* Wed Apr 11 2018 Liz Nemsick <lnemsick.simp@gmail.com> - 4.1.0
- 'simp config' bug fixes
  - Fixed bug in which '{' and '}' characters in console error messages
    resulted in obscure Ruby parsing failures.
  - Fixed bug in which existing non-local NTP servers configuration
    was not presented to the user as a recommended value for
    simp_options::ntpd::servers.
  - Fixed a bug in simp config in which the grub password could
    be **silently** generated and set when the -f option was used.
    The user would have no way to figuring out the value of the
    grub password in that scenario.
- 'simp config' enhancements
  - Reworked password entry to act more like traditional Linux password
    changing programs
  - Improved input validation and error handling:
    - Improved password validation. This validation now uses pwscore,
      when available.  cracklib-check is used otherwise.
      **CAUTION**:  Existing passwords may not pass current validation.
    - When interactive operation is permitted, always query the user for
      replacement values for invalid answers provided by file or command
      command line KEY=VALUE input.  Previously, for items that
      'simp config' would normally automatically assign without user
      input, 'simp config' would automatically (and sometimes
      silently), replace the invalid values.  This both hid errors
      and yielded unexpected settings.
    - Verify <password, password hash> pairs provided by file or
      command line KEY=VALUE input are valid.  Previously, a user
      could pre-assign LDAP Bind/Sync passwords that did not match
      their respective password hashes.
    - Log problems with invalid answers provided by file or command
      line KEY=VALUE input when the answer is processed, not when
      it is first read in.  Previously, validation error messages
      were totally disassociated from the values causing the errors.
  - Added an option to disable queries (-D,--disable-queries) whether or
    not an input answers file is being used.  This feature is a
    functioning replacement for the previously removed -ff capability.
  - Deprecated the --non-interactive long name of -f in favor of
    a more accurately-named replacement, --force-defaults.
    --non-interactive will be removed in a future release.
- 'simp passgen'
  - Fixed bug in which password filenames containing one or more '.'
    characters could not be listed, added, or removed.
  - Added password auto-generation capability to password setting
    operation.
  - Added backup of password salt files, when passwords are backed up.
  - Per security best practices, when a password is updated, now
    removes the salt file corresponding to an old password.
  - Improved password validation. This validation now uses pwscore,
    when available.  cracklib-check is used otherwise.
    **CAUTION**:  Existing passwords may not pass current validation.
- General updates
  - No longer emit Ruby backtraces for errors for which a backtrace
    provides no additional information.

* Fri Mar 16 2018 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.5
- Prior to bootstrap, we now ensure that the site.pp and site module
  code is valid so that we don't have confusing delays after waiting for
  multiple failing Puppet runs.
- Clarified the message when bootstrap is locked
- Ensured that backtraces are not displayed to the user on known
  bootstrap failure cases

* Mon Mar 12 2018 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.5
- Set the ownership and permissions of files generated by simp cli,
  instead of allowing them to be set to those of the root user.
  This is part of the fix to the failure of SIMP to bootstrap on a
  system on which root's umask has already been restricted to 077.

* Thu Feb 08 2018 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.5
- Fix bug in which simp config failed to set the GRUB password
  on a CentOS 6 system booted using EFI

* Wed Jan 31 2018 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.5
- Clarify confusing svckill::mode description provided by simp config
- Use modern OS facts in simp config, instead of legacy facts that
  require LSB packages to be installed.

* Mon Oct 16 2017 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.4
- Fix intermittent failure in RPM builds due to missing rubygems

* Thu Aug 31 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.3
- Fix bug in hostname validation that prevented complex hostnames
  such as 'xyz-w-puppet.qrst-a1-b2' to fail validation.

* Mon Jun 12 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.3
- Prompt user for TTYs to allow in /etc/securetty content

* Fri Jun 02 2017 Nick Markowski <nmarkowski@keywcorp.com> - 4.0.3
- simp bootstrap update:
  - Back up and remove /etc/puppetlabs/puppet/auth.conf

* Fri Jun 02 2017 Trevor Vaughan <tvaughan@onyxpoint.com> - 4.0.2
- Changed chown command to also handle PE
  - Thanks to Bryan Belanger for the PR!
- Made the Puppetserver tmp dir code consistent with the rest of the chmods

* Mon May 22 2017 Nick Markowski <nmarkowski@keywcorp.com> - 4.0.1
- simp config update:
  - We noticed inconsistent behavior when spawning commands with
    pipes, particularly a pipe to xargs.  Item execute has been
    re-tooled to reject pipes, and provide users with a way to
    chain commands while mitigating code flux due to change in API.
  - Added the run_command method to Cli::Config::Item
  - Action items updated:
    - update_os_yum_repositories_action
    - check_server_yum_config_action

* Thu Apr 06 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.0
- simp bootstrap update:
  - Tweak post-bootstrap text to remove instructions to run
    puppet and to make it more clear that the user must reboot.
  - Do not tell user existing certificates have been preserved,
    when none exist.

* Tue Apr 04 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.0
- simp bootstrap update:
  - Minor tweak to ssldir removal logic and messages

* Mon Apr 03 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.0
- simp config changes:
  - Reworked YUM-related queries to reflect changes to simp::yum.
    Now, for non-ISO installs, you have the option to set up
    SIMP repos that pull from SIMP internet repositories.
    Otherwise, the configuration of YUM repositories for the
    SIMP server and SIMP clients is left to the installer.

* Thu Mar 30 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.0
- simp config updates:
  - When SIMP was not installed via RPM, warn operator about
    potential system lockout and then prevent 'simp bootstrap'
    from running, until the operator manually verifies the
    problem has been addressed/is not an issue.
  - Update location to FakeCA

* Mon Mar 27 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.0
- simp config updates:
  - Add query for svckill::mode to simp scenario
  - Refactored generation of scenario configuration YAML, to
    support, more readily, the different configuration requirements
    of each scenario.

* Thu Mar 23 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 4.0.0
- simp passgen updates:
  - Fixed bug that prevented removal of passwords by simp passgen
    (call to non-existent show_password())
  - Updated simp passgen operation to reflect environments
  - Added simp passgen command-line option to specify whether the
    user will be prompted for backup operations when a password is
    set.
  - Added spec tests.
- simp config updates:
  - Adjust spacing of logged output

* Tue Mar 07 2017 Nick Markowski <nmarkowski@keywcorp.com> - 3.0.0
- Updated simp bootstrap for SIMP-6:
-  There is now only one tagged run, simp + pupmod. The puppetserver
   is fully configured at the end of the run, clearing up all
   messy restarts of the service during the rest of the bootstrap.
-  For now, all other base modules are two run idempotent, so tagless
   runs have been limited to two in number.
-  Now re-runable. All modified files are backed up.
-  Lock out the puppet agent to ensure the cron job does not kick
   off during bootstrap.
-  Wait for running puppet agents to complete before bootstrapping;
   users can optionally specify --kill_agent.
-  By default, users are prompted to keep or remove puppetserver certs.
   Added --[no]-remove_ssldir so users can run bootstrap without
   interraction.
-  If puppetserver is configured to listen on 8150, the process is
   no longer killed at the end of bootstrap.
-  More verbose output, including debug mode.  Text is organized and
   colorized.
-  Bootstrap log now timestamped.
-  Introduced a safe mode to ignore interrupts, toggle with --unsafe.
-  Added in general error handling.
-  Removed puppet 3 cruft.
-  Tracking is fabulous.

* Thu Mar 02 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 3.0.0
- Update to current list of simp scenarios.  simp-lite is now simp_lite.

* Tue Feb 28 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 2.0.1
- Fix broken dhcp network configuration in simp config

* Wed Feb 15 2017 Nick Markowski <nmarkowski@keywcorp.com> - 2.0.0
- Modified bootstrap to include a pupmod tag, and optimized
  it for SIMP-6.

* Tue Feb 07 2017 Nick Markowski <nmarkowski@keywcorp.com> - 2.0.0
- Bootstrap now curls the puppetserver on the masterport (not the ca_port)
  to check if the puppetserver is running.

* Thu Jan 12 2017 Liz Nemsick <lnemsick.simp@gmail.com> - 2.0.0
- Rework for SIMP 6

* Mon Dec 05 2016 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.24-0
- Suppress `--pluginsync` unless Puppet version is `3.x`

* Thu Oct 20 2016 Liz Nemsick <lnemsick.simp@gmail.com> - 1.0.23-0
- Fix minor bug causing spec tests to fail

* Sat Oct 01 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.22-0
- Changes made to support both SIMP 6 and legacy versions.
- Bundled in highline

* Thu Sep 22 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.21-0
- Updated the Rakefile to use the simp-rake-helpers file
- Updated the SIMP command line to install to /usr/share/simp/ruby and to use
  the AIO ruby if present and the system ruby otherwise.
- Ensure that the 'simp' executable is installed to the actual system bindir

* Fri Aug 12 2016 Liz Nemsick <lnemsick.simp@gmail.com> - 1.0.20-0
- Fix array formatting bugs present when 'simp config' is used with
  Ruby 1.8.7.
- Fix bug with processing of yes/no item defaults, when the
  non-interactive configuration mode of 'simp config' is enabled.
- Print out a summary of actions taken by 'simp config'.
- Adjust 'simp config' processing to ensure any hiera changes are
  made to the site yaml file, not just the template yaml file
  delivered with SIMP.
- Refine 'simp config' configuration descriptions and other output.
- Improved error handling.
- Expand tests.

* Tue Aug 02 2016 Liz Nemsick <lnemsick.simp@gmail.com> - 1.0.19-0
- Fix simp options parsing bug.

* Tue Aug 02 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.18-0
- Fix RPM spec file.

* Wed Jun 22 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.17-0
- Nail 'listen' to a safe version as a runtime dependency for 'guard'

* Tue Feb 02 2016 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.16-0
- Fixed issue with overwriting pre-existing host certificates during 'simp
  config'

* Thu Nov 26 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.15-0
- Fixed mistaken symlink in simp environment

* Mon Nov 16 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.14-0
- Added logic to set sssd::domains to include LDAP when `use_ldap` is true.

* Fri Nov 13 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.13.0
- Replaced `common::` references with `simplib::`

* Mon Nov 09 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.12-0
- Version bump to re-push gem

* Mon Nov 09 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.11-0
- Fixed a bug where the 'production' symlink was getting backed up even if it
  was pointing to the 'simp' directory already.

* Tue Nov 03 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.10-0
- simp::yum::enable_simp_repos set to false in the default SIMP server
  hieradata by default if the system is the yum_server.
- simp::yum::enable_simp_repos set to false for all systems if the SIMP server
  is *not* the YUM server since we will not be able to make a reasonable
  judgement about repository layout.

* Fri Oct 30 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.9-0
- Made 'simp config' item 'puppet::autosign' non-interactive
- Fixed broken documentation path in 'simp doc'

* Thu Oct 15 2015 Nick Markowski <nmarkowski@keywcorp.com> - 1.0.8-0
- Grub passwords are now replaced instead of being amended during config.

* Mon Sep 28 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.7-0
- Ensure that the puppet digest algorithm is set to sha256 prior if FIPS
  mode is enabled in 'simp config'

* Fri Sep 18 2015 Kendall Moore <kmoore@keywcorp.com> - 1.0.6-0
- Set the keylength variable in puppet.conf

* Mon Sep 14 2015 Nick Markowski <nmarkowski@keywcorp.com> - 1.0.5-0
- If selinux is enabled, run fixfiles before the finalization puppet runs
  in bootstrap.

* Wed Aug 26 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.4-0
- Added use_fips item for 'simp config'

* Wed Aug 12 2015 Nick Miller <nick.miller@onyxpoint.com> - 1.0.3-0
- use_ldap can now be set to false.
- Added a function to add ldap to hiera when needed.

* Thu Jul 23 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.2-0
- Fixed UTF-8/ASCII-8BIT encoding error in ruby 1.9+

* Wed Jun 24 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.1-0
- Version bump to account for whatever made the version bump on the Gem

* Fri Apr 24 2015 Nick Markowski <nmarkowski@keywcorp.com> - 1.0.0-0
- Use dist/, not pkg/, for built gems/rpms.  Added dist to the clean list.
- Determine el_version from mock chroot.
- Added pkg metadata to incorporate into build.

* Fri Mar 06 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.0-0
- Initial package

# vim: set syntax=eruby:
