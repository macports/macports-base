# et:ts=4
# portrpmpackage.tcl
# $Id: portrpmpackage.tcl,v 1.6.6.5 2006/02/28 19:49:34 olegb Exp $
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

set com.apple.rpmpackage [target_new com.apple.rpmpackage rpmpackage_main]
target_runtype ${com.apple.rpmpackage} always
target_provides ${com.apple.rpmpackage} rpmpackage
target_requires ${com.apple.rpmpackage} destroot
target_prerun ${com.apple.rpmpackage} rpmpackage_start

options package.destpath

set_ui_prefix

proc rpmpackage_start {args} { 
	global portname portversion portrevision variations portvariants
	
	set time [clock format [clock seconds]]
	ui_msg "::${time}::${portname}-${portversion}-${portrevision}${portvariants}:: rpmpackage start."

	if { ![info exists portvariants] } {
		set portvariants ""

		set vlist [lsort -ascii [array names variations]]

		# Put together variants in the form +foo+bar for the registry
		foreach v $vlist {
			if { ![string equal $v [option os.platform]] && ![string equal $v [option os.arch]] } {
				set portvariants "${portvariants}+${v}"
			} 
		}
	}

}

proc rpmpackage_main {args} {
    global portname portversion portrevision UI_PREFIX

    return [rpmpackage_pkg $portname $portversion $portrevision]
}

proc rpmpackage_pkg {portname portversion portrevision} {
    global UI_PREFIX package.destpath portdbpath destpath workpath prefix portresourcepath categories maintainers description long_description homepage epoch portpath portvariants 
    
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
    
    foreach dir { "${prefix}/src/apple/RPMS" "/usr/src/apple/RPMS" "/darwinports/rpms/RPMS"} {
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
    
    system "rm -f '${workpath}/${portname}${portvariants}.filelist' && touch '${workpath}/${portname}${portvariants}.filelist'"
    #system "cd '${destpath}' && find . -type d | grep -v -E '^.$' | sed -e 's/\"/\\\"/g' -e 's/^./%dir \"/' -e 's/$/\"/' > '${workpath}/${portname}.filelist'"
    system "cd '${destpath}' && find . ! -type d | grep -v /etc/ | sed -e 's/\"/\\\"/g' -e 's/^./\"/' -e 's/$/\"/' >> '${workpath}/${portname}${portvariants}.filelist'"
    system "cd '${destpath}' && find . ! -type d | grep /etc/ | sed -e 's/\"/\\\"/g' -e 's/^./%config \"/' -e 's/$/\"/' >> '${workpath}/${portname}${portvariants}.filelist'"
    write_spec ${specpath} $portname $portversion $portrevision $portvariants $pkg_description $pkg_long_description $category $maintainer $destpath $dependencies $epoch
    system "DP_USERECEIPTS='${portdbpath}/receipts' rpmbuild -bb -v ${rpmdestpath} ${specpath}"
    
	set time [clock format [clock seconds]]
	ui_msg "::${time}::${portname}-${portversion}-${portrevision}${portvariants}:: rpmpackage end."

    return 0
}

proc make_dependency_list {portname} {
    set result {}
    if {[catch {set res [dportsearch $portname no exact]} error]} {
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

proc write_spec {specfile portname portversion portrevision portvariants description long_description category maintainer destroot dependencies epoch} {
    set specfd [open ${specfile} w+]
    set origportname ${portname}${portvariants}
    regsub -all -- "\-" $portversion "_" portversion
    regsub -all -- "\-" $portname "_" portname
    puts $specfd "\#Spec file generated by DarwinPorts
%define distribution DarwinPorts
%define vendor OpenDarwin
%define packager ${maintainer}

Summary: ${description}
Name: ${portname}${portvariants}
Version: ${portversion}
Release: ${portrevision}
Group: ${category}
License: Unknown
BuildRoot: ${destroot}
Epoch: ${epoch}"
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
echo \"Go DarwinPorts\"
%install
%clean
%files -f ${destroot}/../${origportname}.filelist
"
    close $specfd
}
