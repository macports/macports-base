Name: xar
Epoch: 0
Version: 1.4
Release: 1
Summary: The XAR project aims to provide an easily extensible archive format.
Group: Applications/Archivers
License: BSD
URL: http://www.opendarwin.org/projects/%{name}/
Source: http://www.opendarwin.org/projects/%{name}/%{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{epoch}-%{version}-%{release}-root
BuildRequires: libxml2-devel >= 2.6.11
BuildRequires: openssl-devel
BuildRequires: bzip2-libs
BuildRequires: zlib
Requires: bzip2-libs
Requires: libxml2-devel >= 2.6.11
Requires: openssl-devel

%description
The XAR project aims to provide an easily extensible archive format. Important
design decisions include an easily extensible XML table of contents for random
access to archived files, storing the toc at the beginning of the archive to
allow for efficient handling of streamed archives, the ability to handle files
of arbitrarily large sizes, the ability to choose independent encodings for
individual files in the archive, the ability to store checksums for individual
files in both compressed and uncompressed form, and the ability to query the
table of content's rich meta-data.

%package devel
Summary: Libraries and header files required for xar.
Group: Development/Libraries
Provides: lib%{name}.so
Requires: %{name} = %{epoch}:%{version}-%{release}

%description devel
Libraries and header files required for xar.

%prep
%setup -q -n %{name}-%{version}

%build
%configure
%{__make}

%install
%{__rm} -rf $RPM_BUILD_ROOT
%makeinstall

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc LICENSE TODO
%{_bindir}/%{name}

%files devel
%{_includedir}/%{name}/%{name}.h
%{_libdir}/lib%{name}.so
%{_libdir}/lib%{name}.1.so

%changelog
* Thu Feb 23 2005 Rob Braun <bbraun@opendarwin.org> - 0:1.2-1
- 1.4
* Mon Oct 24 2005 Rob Braun <bbraun@opendarwin.org> - 0:1.2-1
- 1.3
* Wed Sep 21 2005 Jason Corley <jason.corley@gmail.com> - 0:1.1-1
- 1.1
- correct library version
- add specific version to libxml requirements

* Fri Sep 09 2005 Jason Corley <jason.corley@gmail.com> - 0:1.0-1
- 1.0

* Sat Apr 23 2005 Jason Corley <jason.corley@gmail.com> - 0:0.0.0-0.20050423.0
- Initial RPM release.

