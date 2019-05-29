#
# spec file for package yast2-bootloader
#
# Copyright (c) 2016 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-bootloader
Version:        4.2.2
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Url:            http://github.com/yast/yast-bootloader
BuildRequires:  yast2 >= 3.1.176
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  yast2-ruby-bindings >= 1.0.0
# Y2Storage::Mountable#mount_path
BuildRequires:  yast2-storage-ng >= 4.0.90
# lenses needed also for tests
BuildRequires:  augeas-lenses
BuildRequires:  rubygem(%rb_default_ruby_abi:cfa_grub2) >= 1.0.1
BuildRequires:  rubygem(%rb_default_ruby_abi:rspec)
BuildRequires:  rubygem(%rb_default_ruby_abi:yast-rake)
PreReq:         /bin/sed %fillup_prereq
# Base classes for inst clients
Requires:       parted
# Yast::Execute class
Requires:       yast2 >= 3.1.176
Requires:       yast2-core >= 2.18.7
Requires:       yast2-packager >= 2.17.24
Requires:       yast2-pkg-bindings >= 2.17.25
# Y2Storage::Mountable#mount_path
Requires:       yast2-storage-ng >= 4.0.90
# Support for multiple values in GRUB_TERMINAL
Requires:       rubygem(%rb_default_ruby_abi:cfa_grub2) >= 1.0.1
# lenses are needed as cfa_grub2 depends only on augeas bindings, but also
# lenses are needed here
Requires:       augeas-lenses

Requires:       yast2-ruby-bindings >= 1.0.0

# only recommend syslinux, as it is not needed when generic mbr is not used (bsc#1004229)
%ifarch %ix86 x86_64
Recommends:     syslinux
%endif

Summary:        YaST2 - Bootloader Configuration
License:        GPL-2.0-or-later
Group:          System/YaST

%description
This package contains the YaST2 component for bootloader configuration.

%prep
%setup -n %{name}-%{version}

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"

%post
%{fillup_only -n bootloader}

%files
%defattr(-,root,root)

# menu items

%dir %{yast_desktopdir}
%{yast_desktopdir}/bootloader.desktop

%dir %{yast_moduledir}
%{yast_moduledir}/*
%dir %{yast_clientdir}
%{yast_clientdir}/bootloader*.rb
%{yast_clientdir}/inst_*.rb
%dir %{yast_ybindir}
%{yast_ybindir}/*
%dir %{yast_scrconfdir}
%{yast_scrconfdir}/*.scr
%{yast_fillupdir}/*
%dir %{yast_schemadir}
%dir %{yast_schemadir}/autoyast
%dir %{yast_schemadir}/autoyast/rnc
%{yast_schemadir}/autoyast/rnc/bootloader.rnc
%{yast_libdir}/bootloader
%{yast_icondir}

%dir %{yast_docdir}
%license COPYING
%doc %{yast_docdir}/README.md
%doc %{yast_docdir}/CONTRIBUTING.md

%changelog
