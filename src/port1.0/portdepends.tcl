# ex:ts=4
# portdepends.tcl
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

# the 'main' target is provided by this package
# main is a magic target and should not be replaced

package provide portdepends 1.0
package require portutil 1.0

register com.apple.depends.fetch target depends_main always
register com.apple.depends.fetch provides depends_fetch

register com.apple.depends.build target depends_main always
register com.apple.depends.build provides depends_build

register com.apple.depends.run target depends_main always
register com.apple.depends.run provides depends_run

register com.apple.depends.extract target depends_main always
register com.apple.depends.extract provides depends_extract

register com.apple.depends.lib target depends_main always
register com.apple.depends.lib provides depends_lib

# define options
options depends_fetch depends_build depends_run depends_extract depends_lib
# Export options via PortInfo
options_export depends_lib depends_run

# depends_resolve
# XXX - Architecture specific
# XXX - Rely on information from internal defines in cctools/dyld:
# define DEFAULT_FALLBACK_FRAMEWORK_PATH
# /Library/Frameworks:/Library/Frameworks:/Network/Library/Frameworks:/System/Library/Frameworks
# define DEFAULT_FALLBACK_LIBRARY_PATH /lib:/usr/local/lib:/lib:/usr/lib
# Environment variables DYLD_FRAMEWORK_PATH, DYLD_LIBRARY_PATH,
# DYLD_FALLBACK_FRAMEWORK_PATH, and DYLD_FALLBACK_LIBRARY_PATH take precedence

proc depends_main {id} {
    global prefix
    if {[regexp .*\..*\.depends\.(.*) $id match name] != 1} {
	return 0
    }
    set name depends_$name
    global $name env
    if {![info exists $name]} {
	return 0
    }
    upvar #0 $name upname
    foreach depspec $upname {
	if {[regexp {([A-Za-z\./0-9]+):([A-Za-z0-9\.$^\?\+\(\)\|\\]+):([A-Za-z\./0-9]+)} "$depspec" match deppath depregex portname] == 1} {
	    switch -exact -- $deppath {
		lib {
		    if {[info exists env(DYLD_FRAMEWORK_PATH)]} {
			lappend search_path $env(DYLD_FRAMEWORK_PATH)
		    } else {
			lappend search_path /Library/Frameworks /Library/Frameworks /Network/Library/Frameworks /System/Library/Frameworks
		    }
		    if {[info exists env(DYLD_FALLBACK_FRAMEWORK_PATH)]} {
			lappend search_path $env(DYLD_FALLBACK_FRAMEWORK_PATH)
		    }
		    if {[info exists env(DYLD_LIBRARY_PATH)]} {
			lappend search_path $env(DYLD_LIBRARY_PATH)
		    } else {
			lappend search_path /lib /usr/local/lib /lib /usr/lib /op/local/lib /usr/X11R6/lib ${prefix}/lib
		    }
		    if {[info exists env(DYLD_FALLBACK_LIBRARY_PATH)]} {
			lappend search_path $env(DYLD_LIBRARY_PATH)
		    }
		    regsub {\.} $depregex {\.} depregex
		    set depregex \^$depregex.*\\.dylib\$
		}
		bin {
		    set search_path [split $env(PATH) :]
		    set depregex \^$depregex\$
		}
		default {
		    set search_path [split $deppath :]
		}
	    }
	}
    foreach path $search_path {
	if {![file isdirectory $path]} {
		continue
	}
	foreach filename [readdir $path] {
		if {[regexp $depregex $filename] == 1} {
			ui_debug "Found Dependency: path: $path filename: $filename regex: $depregex"
			set found yes
			break
		}
	}
	if {[tbool found]} {
	    break
	}
    }
    if {[tbool found]} {
	unset found
	continue
    }
    ui_debug "Building $portname"
    array set options [list]
    array set variations [list]
    array set portinfo [dportmatch ^$portname\$]
    if {[array size portinfo] == 0} {
        ui_error "Dependency $portname not found"
        return -code error "Dependency $portname not found"
    }
    set porturl $portinfo(porturl)
    set worker [dportopen $porturl options variations]
	if {[catch {dportexec $worker install} result]} {
		ui_error "Build of $portname failed: $result"
		dportclose $worker
        return -code error "Build of $portname failed: $result"
	}
	if {[catch {dportexec $worker clean} result]} {
		ui_error "Clean of $portname failed: $result"
    }
    dportclose $worker
	}
    return 0
}
