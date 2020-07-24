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

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#


Name:           yast2-nis-client
Summary:        YaST2 - Network Information Services (NIS, YP) Configuration
Version:        4.3.1
Release:        0
Url:            https://github.com/yast/yast-nis-client
Group:          System/YaST
License:        GPL-2.0-only

Source0:        %{name}-%{version}.tar.bz2

# SuSEfirewall2_* services merged into one service yast2-2.23.17
BuildRequires:  yast2 >= 2.23.17
BuildRequires:  gcc-c++ doxygen yast2-core-devel update-desktop-files libtool
# Nsswitch#Write
BuildRequires:  yast2-pam >= 4.3.0
BuildRequires:  libnsl-devel
BuildRequires:  libtirpc-devel
BuildRequires:  yast2-devtools >= 4.2.2
BuildRequires:  rubygem(%rb_default_ruby_abi:rspec)

# Wizard::SetDesktopTitleAndIcon
Requires:       yast2 >= 2.21.22
Requires:       yast2-network
# Nsswitch#Write
Requires:       yast2-pam >= 4.3.0
Requires:       yast2-ruby-bindings >= 1.0.0
Requires:       yp-tools

# .net.hostnames.rpc
Conflicts:      yast2-core < 2.8.0

Provides:       yast2-config-nis yast2-config-nis-devel
Provides:       yast2-trans-nis
Provides:       yast2-config-network:/usr/lib/YaST2/clients/lan_ypclient.ycp

Obsoletes:      yast2-config-nis yast2-config-nis-devel
Obsoletes:      yast2-trans-nis
Obsoletes:      yast2-nis-client-devel-doc

%description
The YaST2 component for NIS configuration. NIS is a service similar to
yellow pages.

%prep
%setup -q

%build
%yast_build

%install
%yast_install
%yast_metainfo

%files
%{yast_yncludedir}
%{yast_clientdir}
%{yast_moduledir}
%{yast_desktopdir}
%{yast_metainfodir}
%{yast_agentdir}
%{yast_plugindir}
%{yast_scrconfdir}
%{yast_schemadir}
%{yast_icondir}
%doc %{yast_docdir}
%license COPYING
