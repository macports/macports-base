# et:ts=4
# portsrpm.tcl
# $Id$
#
# Copyright (c) 2007, 2009, 2011, 2013 The MacPorts Project
# Copyright (c) 2002 - 2003 Apple Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of Apple Inc. nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

package provide portsrpm 1.0
package require portutil 1.0
package require portfetch 1.0

set org.macports.srpm [target_new org.macports.srpm portsrpm::srpm_main]
target_runtype ${org.macports.srpm} always
target_provides ${org.macports.srpm} srpm
target_requires ${org.macports.srpm} checksum

namespace eval portsrpm {
}

options package.destpath

# Set up defaults
default srpm.asroot yes

set_ui_prefix

proc portsrpm::srpm_main {args} {
    global subport version revision UI_PREFIX

    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating SRPM package for %s-%s"] ${subport} ${version}]"

    return [srpm_pkg $subport $version $revision]
}

proc portsrpm::srpm_pkg {portname portversion portrevision} {
    global UI_PREFIX package.destpath portdbpath destpath workpath distpath \
           prefix categories maintainers description long_description \
           homepage epoch portpath distfiles os.platform os.arch os.version \
           os.major

    set fetch_urls {}
    portfetch::checkfiles fetch_urls

    set rpmdestpath ""
    if {![string equal ${package.destpath} ${workpath}] && ![string equal ${package.destpath} ""]} {
        set pkgpath ${package.destpath}
        file mkdir ${pkgpath}/BUILD \
                   ${pkgpath}/RPMS \
                   ${pkgpath}/SOURCES \
                   ${pkgpath}/SPECS \
                   ${pkgpath}/SRPMS
        set rpmdestpath "--define '_topdir ${pkgpath}'"
    }

    foreach dir [list "${prefix}/src/macports/SRPMS" "${prefix}/src/apple/SRPMS" "/usr/src/apple/SRPMS" "/macports/rpms/SRPMS"] {
        foreach arch {"src" "nosrc"} {
            set rpmpath "$dir/${portname}-${portversion}-${portrevision}.${arch}.rpm"
	    if {[file readable $rpmpath] && ([file mtime ${rpmpath}] >= [file mtime ${portpath}/Portfile])} {
                ui_debug "$rpmpath"
                ui_msg "$UI_PREFIX [format [msgcat::mc "SRPM package for %s-%s is up-to-date"] ${portname} ${portversion}]"
                return 0
            }
        }
    }

    set specpath ${workpath}/${portname}-port.spec
    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage categories maintainers} {
        if {![info exists $variable]} {
            set pkg_$variable ""
        } else {
            set pkg_$variable [set $variable]
        }
    }
    set category   [lindex [split $categories " "] 0]
    set license    "Unknown"
    set maintainer $maintainers

    set dependencies {}
    # get deplist
    set deps [make_dependency_list $portname]
    set deps [lsort -unique $deps]
    foreach dep $deps {
        set name [lindex [split $dep /] 0]
        set vers [lindex [split $dep /] 1]
        # don't re-package ourself
        if {$name != $portname} {
            lappend dependencies "${name} >= ${vers}"
        }
    }

    # true = .src.rpm (with distfiles), false = .nosrc.rpm (without distfiles)
    set src false

    #set sourcespath ${prefix}/src/macports/SOURCES
    set sourcespath "`rpm --eval %{_sourcedir}`"

    system "cp -p ${portpath}/Portfile ${sourcespath}/$portname-Portfile"
    if {[info exists ${portpath}/files]} {
        system "cd ${portpath} && zip -r -q ${sourcespath}/$portname-files.zip files -x \\*.DS_Store -x files/.svn\\*"
        set zip $portname-files.zip
    } else {
        set zip ""
    }
    foreach dist $distfiles {
        system "cp -p ${distpath}/${dist} ${sourcespath}/${dist}"
    }

    write_port_spec ${specpath} $portname $portversion $portrevision $pkg_description $pkg_long_description $pkg_homepage $category $license $maintainer $distfiles $fetch_urls $dependencies $epoch $src $zip
    system "rpmbuild -bs -v --nodeps ${rpmdestpath} ${specpath}"

    return 0
}

proc portsrpm::make_dependency_list {portname} {
    set result {}
    if {[catch {set res [mport_lookup $portname]} error]} {
		global errorInfo
		ui_debug "$errorInfo"
        ui_error "port lookup failed: $error"
        return 1
    }
    foreach {name array} $res {
        array set portinfo $array

        if {[info exists portinfo(depends_fetch)] || [info exists portinfo(depends_extract)]
            || [info exists portinfo(depends_build)] || [info exists portinfo(depends_lib)]} {
            # get the union of depends_fetch, depends_extract, depends_build and depends_lib
            # xxx: only examines the portfile component of the depspec
            set depends {}
            if {[info exists portinfo(depends_fetch)]} { eval "lappend depends $portinfo(depends_fetch)" }
            if {[info exists portinfo(depends_extract)]} { eval "lappend depends $portinfo(depends_extract)" }
            if {[info exists portinfo(depends_build)]} { eval "lappend depends $portinfo(depends_build)" }
            if {[info exists portinfo(depends_lib)]} { eval "lappend depends $portinfo(depends_lib)" }

            foreach depspec $depends {
                set dep [lindex [split $depspec :] end]

                # xxx: nasty hack
                if {$dep != "XFree86"} {
                    eval "lappend result [make_dependency_list $dep]"
                }
            }
        }
        lappend result $portinfo(name)/$portinfo(version)
        unset portinfo
    }
    ui_debug "dependencies for ${portname}: $result"
    return $result
}

proc portsrpm::word_wrap {orig Length} {
    set pos 0
    set line ""
    set text ""

    set words [split $orig]
    set numWords [llength $words]
    for {set cnt 0} {$cnt < $numWords} {incr cnt} {
	set w [lindex $words $cnt]
	set wLen [string length $w]

	if {($pos+$wLen < $Length)} {
	    # append word to current line
	    if {$pos} {append line " "; incr pos}
	    append line $w
	    incr pos $wLen
	} else {
	    # line full => write buffer and  begin a new line
	    if {[string length $text]} {append text "\n"}
	    append text $line
	    set line $w
	    set pos $wLen
	}
    }

    if {[string length $text]} {append text "\n"}
    if {[string length $line]} {append text $line}
    return $text
}

proc portsrpm::write_port_spec {specfile portname portversion portrevision description long_description homepage category license maintainer distfiles fetch_urls dependencies epoch src zip} {
    set specfd [open ${specfile} w+]
    set origportname ${portname}
    regsub -all -- "\-" $portversion "_" portversion
    regsub -all -- "\-" $portname "_" portname
    puts $specfd "\#Spec file generated by MacPorts
%define distribution MacPorts
%define vendor MacPorts
%define packager ${maintainer}

Summary: ${description}
Name: ${portname}
Version: ${portversion}
Release: ${portrevision}
Group: ${category}
License: ${license}
URL: ${homepage}
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Source0: ${portname}-Portfile"
    if {$zip != ""} {
        puts $specfd "Source1: $zip"
    }
    if {[expr ${epoch} != 0]} {
	    puts $specfd "Epoch: ${epoch}"
    }
    set first 2
    set count $first
    puts $specfd "#distfiles"
    foreach file ${distfiles} {

        puts -nonewline $specfd "Source${count}: "
        if {![info exists $fetch_urls]} {
        foreach {url_var distfile}  ${fetch_urls} {
            if {[string equal $distfile $file]} {
                 global portfetch::$url_var master_sites
                 set site [lindex [set $url_var] 0]
                 set file [portfetch::assemble_url $site $distfile]
                 break
            }
        }
        }
        puts $specfd $file
        if (!$src) {
            puts $specfd "NoSource: $count"
        }
        incr count
    }
    puts $specfd "AutoReq: no"
    if {[llength ${dependencies}] != 0} {
	foreach require ${dependencies} {
	    puts $specfd "BuildRequires: [regsub -all -- "\-" $require "_"]"
	}
    }
    set wrap_description [word_wrap ${long_description} 72]
    if {$zip != ""} {
        set and "-a 1"
    } else {
        set and ""
    }
    puts $specfd "
%description
$wrap_description

%prep
%setup -c $and -T
cp -p %{SOURCE0} Portfile
#prepare work area
port fetch
port checksum
port extract
port patch

%build
port configure
port build

%install
rm -rf \$RPM_BUILD_ROOT
mkdir -p \$RPM_BUILD_ROOT
port destroot
port rpm

%clean
port clean"
    close $specfd
}
