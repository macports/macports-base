# ex:ts=4
# portpackage.tcl
#
# Copyright (c) 2002 Apple Computer, Inc.
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

package provide portpackage 1.0
package require portutil 1.0

register com.apple.package target package_main package_init
register com.apple.package provides package
register com.apple.package requires main

# define options
options package.type

# Set defaults
default package.type tarball

set UI_PREFIX "---> "

proc package_init {args} {
}

proc package_main {args} {
    global portname portversion package.type UI_PREFIX

    set rfile [registry_exists $portname $portversion]
    if ![string length $rfile] {
	ui_error "Package ${portname}-${portversion} not installed on this system"
	return -1
    }
    ui_msg "$UI_PREFIX Creating ${package.type} package for ${portname}-${portversion}"
    if [regexp .bz2$ $rfile] {
	set fd [open "|bunzip2 -c $rfile" r]
    } else {
	set fd [open $rfile r]
    }
    set entry [read $fd]
    close $fd

    # For now the only package type we support is "tarball" but move that
    # into another routine anyway so that this is abstract enough.

    return [package_tarball $portname $portversion $entry]
}

# Make a tarball version of a package.  This is our "built-in" packaging
# method.
proc package_tarball {portname portversion entry} {
    global ports_verbose sysportpath

    set rfile [registry_exists $portname $portversion]
    set ix [lsearch $entry contents]
    if {$ix >= 0} {
	set contents [lindex $entry [incr ix]]
	set plist [mkstemp /tmp/XXXXXXXX]
	set pfile [lindex $plist 0]
	foreach f $contents {
	    set fname [lindex $f 0]
	    puts $pfile $fname
	}
	puts $pfile $rfile
	close $pfile
	if [tbool ports_verbose] {
	    set verbose v
	} else {
	    set verbose ""
	}
	set pkgdir [join $sysportpath packages]
	if [file isdirectory $pkgdir] {
	    set ptarget $pkgdir/${portname}-${portversion}.tar.gz
	} else {
	    set ptarget ${portname}-${portversion}.tar.gz
	}
	if [catch {exec gnutar -T [lindex $plist 1] -czPp${verbose}f ${ptarget}} err] {
	    ui_error "Package creation failed - gnutar returned error status: $err"
	    exec rm [lindex $plist 1]
	    return -1
	}
	exec rm [lindex $plist 1]
    } else {
	ui_error "Bad registry entry for ${portname}-${portversion}, no contents"
	return -1
    }
    return 0
}
