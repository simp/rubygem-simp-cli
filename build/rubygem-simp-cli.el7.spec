# Generated from simp-cli-0.7.0.gem by gem2rpm -*- rpm-spec -*-
# vim: set syntax=eruby:
%global gemname simp-cli

%global gemdir /usr/local/share/gems
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global ruby_version 2.0

# gem2ruby's method of installing gems into mocked build roots will blow up
# unless this line is present:
%define _unpackaged_files_terminate_build 0

Summary: a cli interface to configure/manage SIMP
Name: rubygem-%{gemname}
Version: 1.0.13
Release: 0%{?dist}
Group: Development/Languages
License: Apache-2.0
URL: https://github.com/NationalSecurityAgency/rubygem-simp-cli
Source0: %{gemname}-%{version}.gem
# NOTE: in el6 this was ruby(abi):
Requires: ruby(runtime_executable) => %{ruby_version}
Requires: ruby(rubygems)
Requires: puppet => 3
Requires: rubygem-highline => 1.6.1
Requires: facter => 2.2
BuildRequires: ruby(runtime_executable) => %{ruby_version}
BuildRequires: ruby(rubygems)
BuildRequires: ruby
BuildArch: noarch
Provides: rubygem(%{gemname}) = %{version}

%description
simp-cli provides the 'simp' command to configure and manage SIMP.


%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires: %{name} = %{version}-%{release}
BuildArch: noarch

%description doc
Documentation for %{name}


%prep
%setup -q -c -T
echo "======= %setup PWD: ${PWD}"
echo "======= %setup gemdir: %{gemdir}"
mkdir -p .%{gemdir}
mkdir -p .%{_bindir} # NOTE: this is needed for el7
gem install --local --install-dir .%{gemdir} \
            --bindir .%{_bindir} \
            --force %{SOURCE0}

%build

%install
mkdir -p %{buildroot}%{gemdir}
cp -pa .%{gemdir}/* \
        %{buildroot}%{gemdir}/

mkdir -p %{buildroot}%{_bindir}
cp -pa .%{_bindir}/* \
        %{buildroot}%{_bindir}/

find %{buildroot}%{geminstdir}/bin -type f | xargs chmod a+x

%files
%dir %{geminstdir}
%{_bindir}/simp
%{geminstdir}/bin
%{geminstdir}/lib
%exclude %{gemdir}/cache/%{gemname}-%{version}.gem
%{gemdir}/specifications/%{gemname}-%{version}.gemspec

%files doc
%doc %{gemdir}/doc/%{gemname}-%{version}


%changelog
* Fri Nov 13 2015 Chris Tessmer <chris.tessmer@onyxpoint.com> - 1.0.13.0
- replaced `common::` references with `simplib::`

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

