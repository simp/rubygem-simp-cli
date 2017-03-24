%global gemname simp-cli

%global gemdir /usr/share/simp/ruby
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global cli_version 3.0.1
%global highline_version 1.7.8

# gem2ruby's method of installing gems into mocked build roots will blow up
# unless this line is present:
%define _unpackaged_files_terminate_build 0

Summary: a cli interface to configure/manage SIMP
Name: rubygem-%{gemname}
Version: %{cli_version}
Release: 0
Group: Development/Languages
License: Apache-2.0
URL: https://github.com/simp/rubygem-simp-cli
Source0: %{name}-%{cli_version}-%{release}.tar.gz
Source1: %{gemname}-%{cli_version}.gem
Requires: puppet >= 3
Requires: facter >= 2.2
Requires: rubygem(%{gemname}-highline) >= %{highline_version}
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
* Fri Mar 24 2017  Liz Nemsick <lnemsick.simp@gmail.com> - 3.0.1
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
