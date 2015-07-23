# Generated from simp-cli-0.7.0.gem by gem2rpm -*- rpm-spec -*-
# NOTE: Heavily modified because gem2rpm is serviceable but not awesome

# vim: set syntax=eruby:
%global gemname simp-cli

# Fs up spectacularly in RVM; hardcoding to 1.8
#%global gemdir %(ruby -rubygems -e 'puts Gem::dir' 2>/dev/null)
%global gemdir /usr/lib/ruby/gems/1.8
%global geminstdir %{gemdir}/gems/%{gemname}-%{version}
%global rubyabi 1.8

# gem2ruby's method of installing gems into mocked build roots will blow up
# unless this line is present:
%define _unpackaged_files_terminate_build 0

Summary: a cli interface to configure/manage SIMP
Name: rubygem-%{gemname}
Version: 1.0.2
Release: 0%{?dist}
Group: Development/Languages
License: Apache-2.0
URL: https://github.com/NationalSecurityAgency/rubygem-simp-cli
Source0: %{gemname}-%{version}.gem
Requires: ruby(abi) = %{rubyabi}
Requires: ruby(rubygems)
Requires: puppet => 3
Requires: rubygem-highline => 1.6.1
Requires: facter => 2.2
# Requires: puppet < 4
# Requires: rubygem(puppet) => 3       # not packaged as rubygem-puppet
# Requires: rubygem(puppet) < 4        # not packaged as rubygem-puppet
# Requires: rubygem(highline) => 1.6.1 # error!
# Requires: rubygem(highline) < 1.7    # error!
# Requires: rubygem(facter) => 2       # not packaged as rubygem-facter
# Requires: rubygem(facter) < 3        # not packaged as rubygem-facter
#Requires: facter < 3                  # error!
BuildRequires: ruby(abi) = %{rubyabi}
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
mkdir -p .%{gemdir}
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
