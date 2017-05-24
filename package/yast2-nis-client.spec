#
# spec file for package yast2-nis-client
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


Name:           yast2-nis-client
Version:        3.2.1
Release:        0
Url:            https://github.com/yast/yast-nis-client

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

Group:          System/YaST
License:        GPL-2.0
# SuSEfirewall2_* services merged into one service yast2-2.23.17
BuildRequires:	yast2 >= 2.23.17
BuildRequires:	gcc-c++ perl-XML-Writer doxygen yast2-core-devel yast2-testsuite yast2-pam update-desktop-files libtool
BuildRequires:  yast2-devtools >= 3.1.10
# Wizard::SetDesktopTitleAndIcon
Requires:	yast2 >= 2.21.22
Requires:       yast2-pam yast2-network
# .net.hostnames.rpc
Conflicts:      yast2-core < 2.8.0

Provides:	yast2-config-nis yast2-config-nis-devel
Obsoletes:	yast2-config-nis yast2-config-nis-devel
Provides:	yast2-trans-nis
Obsoletes:	yast2-trans-nis
Provides:	yast2-config-network:/usr/lib/YaST2/clients/lan_ypclient.ycp
Obsoletes:	yast2-nis-client-devel-doc

Requires:       yast2-ruby-bindings >= 1.0.0
Requires:	yp-tools

Summary:	YaST2 - Network Information Services (NIS, YP) Configuration

%description
The YaST2 component for NIS configuration. NIS is a service similar to
yellow pages.

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/nis
%{yast_yncludedir}/nis/ui.rb
%{yast_clientdir}/nis.rb
%{yast_clientdir}/nis-client.rb
%{yast_clientdir}/nis_auto.rb
%{yast_moduledir}/Nis.*
%{yast_desktopdir}/nis.desktop
%{yast_agentdir}/ag_yp_conf
%{yast_plugindir}/libpy2ag_ypserv.so.*
%{yast_plugindir}/libpy2ag_ypserv.so
%{yast_plugindir}/libpy2ag_ypserv.la
%{yast_scrconfdir}/cfg_ypbind.scr
%{yast_scrconfdir}/yp_conf.scr
%{yast_scrconfdir}/ypserv.scr
%{yast_scrconfdir}/etc_defaultdomain.scr
%{yast_schemadir}/autoyast/rnc/nis.rnc

%dir %{yast_docdir}
%doc %{yast_docdir}/COPYING
