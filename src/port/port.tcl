#!/usr/bin/tclsh
# port.tcl
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

package require darwinports

# globals
set portdir .

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[-vDq\] \[action\] \[-d portdir\] \[options\]"
}

proc fatal args {
    global argv0
    puts stderr "$argv0: $args"
    exit
}

# Main
set separator 0
array set options [list]
array set variations [list]
for {set i 0} {$i < $argc} {incr i} {
    set arg [lindex $argv $i]
	
    # if -xyz before the separator
    if {$separator == 0 && [regexp {^-([-A-Za-z0-9]+)$} $arg match opt] == 1} {
	if {$opt == "-"} {
	    set separator 1
	} else {
	    foreach c [split $opt {}] {
		if {$c == "v"} {
		    set options(ports_verbose) yes
		} elseif {$c == "D"} {
		    set options(ports_debug) yes
		} elseif {$c == "q"} {
		    set options(ports_quiet) yes
		    set options(ports_verbose) no
		    set options(ports_debug) no
		} elseif {$opt == "d"} {
		    incr i
		    set porturl "file://[lindex $argv $i]"
		} elseif {$opt == "u"} {
		    incr i
		    set porturl [lindex $argv $i]
		} else {
		    print_usage; exit
		}
	    }
	}
	
	# if +xyz -xyz or after the separator
    } elseif {[regexp {^([-+])([-A-Za-z0-9_+\.]+)$} $arg match sign opt] == 1} {
	set variations($opt) $sign
	
	# option=value
    } elseif {[regexp {([A-Za-z0-9_\.]+)=(.*)} $arg match key val] == 1} {
	set options($key) \"$val\"
	
	# action
    } elseif {[regexp {^([A-Za-z0-9/._\-^$\[\[?\(\)\\|\+\*]+)$} $arg match opt] == 1} {
	if [info exists action] {
	    set portname $opt
	} else {
	    set action $opt
	}
    } else {
	print_usage; exit
    }
}

if ![info exists action] {
    set action build
}

if {[catch {dportinit} result]} {
    puts "Failed to initialize ports system, $result"
    exit 1
}

switch -- $action {
    search {
	if ![info exists portname] {
	    puts "You must specify a search pattern"
	    exit 1
	}
	if {[catch {set res [dportsearch $portname]} result]} {
	    puts "port search failed: $result"
	    exit 1
	}
	foreach {name array} $res {
	    array set portinfo $array
	    set portfound 1
	    if ![info exists portinfo(portname)] {
		puts "Invalid port entry, missing portname"
		continue
	    }
	    if ![info exists portinfo(description)] {
		puts "Invalid port entry for $portinfo(portname), missing description"
		continue
	    }
	    puts [format "%-15s\t%s" $portinfo(portname) $portinfo(description)]
	    unset portinfo
	}
	if {![info exists portfound] || $portfound == 0} {
	    puts "No match for $portname found"
	    exit 1
	}
    }
    sync {
	if {[catch {dportsync} result]} {
	    puts "port sync failed: $result"
	    exit 1
	}
    }
    default {
	set target $action
	if {[info exists portname]} {
	    if {[catch {array set portinfo [dportmatch ^$portname\$]} result]} {
		puts $result
		exit 1
	    }
	    if {[array size portinfo] == 0} {
		puts "Port $portname not found"
		exit 1
	    }
	    set porturl $portinfo(porturl)
	}
	if ![info exists porturl] {
	    set porturl file://./
	}
	if {[catch {set workername [dportopen $porturl options variations]} result]} {
	    puts "Unable to open port: $result"
	    exit 1
	}
	if {[catch {set result [dportexec $workername $target]} result]} {
	    puts "Unable to execute port: $result"
	    exit 1
	}

	dportclose $workername
	exit $result
    }
}
