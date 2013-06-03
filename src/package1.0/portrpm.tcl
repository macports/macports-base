# et:ts=4
# portrpm.tcl
# $Id$
#
# Copyright (c) 2005 - 2007, 2009 - 2011, 2013 The MacPorts Project
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

package provide portrpm 1.0
package require portutil 1.0

set org.macports.rpm [target_new org.macports.rpm portrpm::rpm_main]
target_runtype ${org.macports.rpm} always
target_provides ${org.macports.rpm} rpm
target_requires ${org.macports.rpm} archivefetch unarchive destroot

namespace eval portrpm {
}

# Options
options rpm.asroot
options package.destpath

# Set up defaults
default rpm.asroot yes

default rpm.srcdir {${prefix}/src/macports}
default rpm.tmpdir {${prefix}/var/tmp}

set_ui_prefix

proc portrpm::rpm_main {args} {
    global subport version revision UI_PREFIX

    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating RPM package for %s-%s"] ${subport} ${version}]"

    return [rpm_pkg $subport $version $revision]
}

proc portrpm::rpm_pkg {portname portversion portrevision} {
    global UI_PREFIX rpm.asroot package.destpath portdbpath destpath workpath \
           prefix categories maintainers description long_description \
           homepage epoch portpath os.platform os.arch os.version os.major \
           supported_archs configure.build_arch license

    set rpmdestpath ""
    if {![string equal ${package.destpath} ${workpath}] && ![string equal ${package.destpath} ""]} {
        set rpm.asroot no
        set pkgpath ${package.destpath}
        file mkdir ${pkgpath}/BUILD \
                   ${pkgpath}/RPMS \
                   ${pkgpath}/SOURCES \
                   ${pkgpath}/SPECS \
                   ${pkgpath}/SRPMS
        set rpmdestpath "--define '_topdir ${pkgpath}'"
    }

    set rpmbuildarch ""
    if {$supported_archs == "noarch"} {
        set rpmbuildarch "--target noarch"
    } elseif {[variant_exists universal] && [variant_isset universal]} {
        set rpmbuildarch "--target fat"
    } elseif {${configure.build_arch} != ""} {
        set rpmbuildarch "--target ${configure.build_arch}"
    }

    foreach dir [list "${prefix}/src/macports/RPMS" "${prefix}/src/apple/RPMS" "/usr/src/apple/RPMS" "/macports/rpms/RPMS"] {
        foreach arch [list ${configure.build_arch} ${os.arch} "fat" "noarch"] {
            set rpmpath "$dir/${arch}/${portname}-${portversion}-${portrevision}.${arch}.rpm"
	    if {[file readable $rpmpath] && ([file mtime ${rpmpath}] >= [file mtime ${portpath}/Portfile])} {
                ui_debug "$rpmpath"
                ui_msg "$UI_PREFIX [format [msgcat::mc "RPM package for %s-%s is up-to-date"] ${portname} ${portversion}]"
                return 0
            }
        }
    }

    set specpath ${workpath}/${portname}.spec
    # long_description, description, or homepage may not exist
    foreach variable {long_description description homepage categories maintainers} {
        if {![info exists $variable]} {
            set pkg_$variable ""
        } else {
            set pkg_$variable [set $variable]
        }
    }
    set category   [lindex [split $categories " "] 0]
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

	# depend on system (virtual packages for apple stuff)
	lappend dependencies "org.macports.${os.platform}${os.major}"

    set listpath ${workpath}/${portname}.filelist
    system "rm -f '${workpath}/${portname}.filelist' && touch '${workpath}/${portname}.filelist'"
    #system "cd '${destpath}' && find . -type d | grep -v -E '^.$' | sed -e 's/\"/\\\"/g' -e 's/^./%dir \"/' -e 's/$/\"/' > '${workpath}/${portname}.filelist'"
    system "cd '${destpath}' && find . ! -type d | grep -v /etc/ | sed -e 's/\"/\\\"/g' -e 's/^./\"/' -e 's/$/\"/' >> '${workpath}/${portname}.filelist'"
    system "cd '${destpath}' && find . ! -type d | grep /etc/ | sed -e 's/\"/\\\"/g' -e 's/^./%config \"/' -e 's/$/\"/' >> '${workpath}/${portname}.filelist'"
    write_spec ${specpath} ${destpath} ${listpath} $portname $portversion $portrevision $pkg_description $pkg_long_description $pkg_homepage $category $license $maintainer $dependencies $epoch
    system "MP_USERECEIPTS='${portdbpath}/receipts' rpmbuild -bb -v ${rpmbuildarch} ${rpmdestpath} ${specpath}"

    return 0
}

proc portrpm::make_dependency_list {portname} {
    set result {}
    if {[catch {set res [mport_lookup $portname]} error]} {
		global errorInfo
		ui_debug "$errorInfo"
        ui_error "port lookup failed: $error"
        return 1
    }
    foreach {name array} $res {
        array set portinfo $array

        if {[info exists portinfo(depends_run)] || [info exists portinfo(depends_lib)]} {
            # get the union of depends_run and depends_lib
            # xxx: only examines the portfile component of the depspec
            set depends {}
            if {[info exists portinfo(depends_run)]} { eval "lappend depends $portinfo(depends_run)" }
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

proc portrpm::word_wrap {orig Length} {
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

proc portrpm::write_spec {specfile destroot filelist portname portversion portrevision description long_description homepage category license maintainer dependencies epoch} {
    set specfd [open ${specfile} w+]
    set origportname ${portname}
    regsub -all -- "\-" $portversion "_" portversion
    regsub -all -- "\-" $portname "_" portname
    puts $specfd "\#Spec file generated by MacPorts
%define distribution MacPorts
%define vendor MacPorts
%define packager ${maintainer}

%define buildroot ${destroot}
# Avoid cleaning BuildRoot in the pre-install:
%define __spec_install_pre     %{___build_pre}
%define __spec_clean_body      %{nil}

Summary: ${description}
Name: ${portname}
Version: ${portversion}
Release: ${portrevision}
Group: ${category}
License: ${license}
URL: ${homepage}
BuildRoot: ${destroot}
AutoReq: no"
    if {[expr ${epoch} != 0]} {
	    puts $specfd "Epoch: ${epoch}"
    }
    if {[llength ${dependencies}] != 0} {
	foreach require ${dependencies} {
	    puts $specfd "Requires: [regsub -all -- "\-" $require "_"]"
	}
    }
    set wrap_description [word_wrap ${long_description} 72]
    puts $specfd "
%description
$wrap_description

%prep
%build
%install
%clean

%files -f ${filelist}"
    close $specfd
}
