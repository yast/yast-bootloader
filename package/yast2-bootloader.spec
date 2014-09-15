#
# spec file for package yast2-bootloader
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
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
Version:        3.1.94.1
Release:        0

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:	        System/YaST
License:        GPL-2.0+
Url:            http://github.com/yast/yast-bootloader
BuildRequires:	yast2-devtools >= 3.1.10
BuildRequires:	yast2 >= 3.1.0
BuildRequires:  update-desktop-files
BuildRequires:  rubygem(rspec)
BuildRequires:  yast2-storage
PreReq:         /bin/sed %fillup_prereq
# Installation::*version variables
# Wizard::SetDialogTitleAndIcon
Requires:	yast2 >= 3.1.0
Requires:	yast2-packager >= 2.17.24
Requires:	yast2-pkg-bindings >= 2.17.25
Requires:	perl-Bootloader-YAML
Requires:	yast2-core >= 2.18.7
Requires:       yast2-storage >= 2.18.18 parted perl-Compress-Zlib

%ifarch %ix86 x86_64
Requires:	syslinux
%endif

Provides:	yast2-config-lilo yast2-config-bootloader
Obsoletes:	yast2-config-lilo yast2-config-bootloader
Provides:	yast2-agent-liloconf yast2-agent-prom
Obsoletes:	yast2-agent-liloconf yast2-agent-prom
Provides:	yast2-trans-inst-bootloader yast2-trans-lilo yast2-trans-boot
Obsoletes:	yast2-trans-inst-bootloader yast2-trans-lilo yast2-trans-boot
Provides:	y2c_boot y2t_boot
Obsoletes:	y2c_boot y2t_boot
Provides:	y2t_inst-bootloader yast2-agent-liloconf-devel yast2-agent-prom-devel
Obsoletes:	y2t_inst-bootloader yast2-agent-liloconf-devel yast2-agent-prom-devel

Requires:       yast2-ruby-bindings >= 1.0.0

Summary:	YaST2 - Bootloader Configuration

%description
This package contains the YaST2 component for bootloader configuration.

%package devel-doc
Requires:       yast2-bootloader = %version
Group:          System/YaST
Summary:        YaST2 - Bootloader Configuration - Development Documentation

%description devel-doc
This package contains development documentation for using the API
provided by yast2-bootloader package.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%check
make check VERBOSE=1

%install
%yast_install


%post
%{fillup_only -n bootloader}

%files
%defattr(-,root,root)

# menu items

%dir %{yast_desktopdir}
%{yast_desktopdir}/bootloader.desktop

%dir %{yast_yncludedir}
%dir %{yast_yncludedir}/bootloader
%{yast_yncludedir}/bootloader/*
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

%dir %{yast_docdir}
%doc %{yast_docdir}/COPYING

%files devel-doc
%defattr(-,root,root)
%doc %{yast_docdir}/autodocs

