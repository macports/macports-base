# et:ts=4
# portrpmpackage.tcl
# $Id$
#
# Copyright (c) 2002 - 2003 Apple Computer, Inc.
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
# 3. Neither the name of Apple Computer, Inc. nor the names of its contributors
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

package provide portrpmpackage 1.0
package require portutil 1.0

set org.macports.rpmpackage [target_new org.macports.rpmpackage rpmpackage_main]
target_runtype ${org.macports.rpmpackage} always
target_provides ${org.macports.rpmpackage} rpmpackage
target_requires ${org.macports.rpmpackage} destroot

options package.destpath

set_ui_prefix

proc rpmpackage_main {args} {
    global portname portversion portrevision UI_PREFIX
    
    ui_msg "$UI_PREFIX [format [msgcat::mc "Creating RPM package for %s-%s"] ${portname} ${portversion}]"
    
    return [rpmpackage_pkg $portname $portversion $portrevision]
}

proc rpmpackage_pkg {portname portversion portrevision} {
    global UI_PREFIX package.destpath portdbpath destpath workpath prefix portresourcepath categories maintainers description long_description homepage epoch portpath
	global os.platform os.arch os.version
    
    set rpmdestpath ""
    if {![string equal ${package.destpath} ${workpath}] && ![string equal ${package.destpath} ""]} {
        set pkgpath ${package.destpath}
        system "mkdir -p ${pkgpath}/BUILD"
        system "mkdir -p ${pkgpath}/RPMS"
        system "mkdir -p ${pkgpath}/SOURCES"
        system "mkdir -p ${pkgpath}/SPECS"
        system "mkdir -p ${pkgpath}/SRPMS"
        set rpmdestpath "--define '_topdir ${pkgpath}'"
    }
    
    foreach dir { "${prefix}/src/apple/RPMS" "/usr/src/apple/RPMS" "/macports/rpms/RPMS"} {
        foreach arch {"ppc" "i386" "fat"} {
            set rpmpath "$dir/${arch}/${portname}-${portversion}-${portrevision}.${arch}.rpm"
	    if {[file readable $rpmpath] && ([file mtime ${rpmpath}] >= [file mtime ${portpath}/Portfile])} {
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
	regexp {[0-9]+} ${os.version} major
	lappend dependencies "org.macports.${os.arch}"
	lappend dependencies "org.macports.${os.platform}${major}"
    
    system "rm -f '${workpath}/${portname}.filelist' && touch '${workpath}/${portname}.filelist'"
    #system "cd '${destpath}' && find . -type d | grep -v -E '^.$' | sed -e 's/\"/\\\"/g' -e 's/^./%dir \"/' -e 's/$/\"/' > '${workpath}/${portname}.filelist'"
    system "cd '${destpath}' && find . ! -type d | grep -v /etc/ | sed -e 's/\"/\\\"/g' -e 's/^./\"/' -e 's/$/\"/' >> '${workpath}/${portname}.filelist'"
    system "cd '${destpath}' && find . ! -type d | grep /etc/ | sed -e 's/\"/\\\"/g' -e 's/^./%config \"/' -e 's/$/\"/' >> '${workpath}/${portname}.filelist'"
    write_spec ${specpath} $portname $portversion $portrevision $pkg_description $pkg_long_description $category $maintainer $destpath $dependencies $epoch
    system "MP_USERECEIPTS='${portdbpath}/receipts' rpmbuild -bb -v ${rpmdestpath} ${specpath}"
    
    return 0
}

proc make_dependency_list {portname} {
    set result {}
    if {[catch {set res [mport_search "^$portname\$"]} error]} {
		global errorInfo
		ui_debug "$errorInfo"
        ui_error "port search failed: $error"
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

proc write_spec {specfile portname portversion portrevision description long_description category maintainer destroot dependencies epoch} {
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
License: Unknown
BuildRoot: ${destroot}
Epoch: ${epoch}
AutoReqProv: no"
    if {[llength ${dependencies}] != 0} {
	foreach require ${dependencies} {
	    puts $specfd "Requires: [regsub -all -- "\-" $require "_"]"
	}
    }
    puts $specfd "
%description
${long_description}
%prep
%build
echo \"Go MacPorts\"
%install
%clean
%files -f ${destroot}/../${origportname}.filelist
"
    close $specfd
}
