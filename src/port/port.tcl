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
    puts "Usage: $argv0 \[-vDq\] \[target\] \[-d portdir\] \[options\]"
}

proc fatal args {
    global argv0
    puts stderr "$argv0: $args"
    exit
}

# Main
set target "build"
set separator 0
array set options [list]
array set variations [list]
for {set i 0} {$i < $argc} {incr i} {
	set arg [lindex $argv $i]
	
	# if -xyz before the separator
	if {$separator == 0 && [regexp {^-([-A-Za-z0-9]+)$} $arg match opt] == 1} {
		if {$opt == "-"} {
			set separator 1
		} elseif {$opt == "d"} {
			incr i
			set portdir [lindex $argv $i]
		} else {
			foreach c [split $opt {}] {
				if {$c == "v"} {
					ports_verbose yes
				} elseif {$c == "D"} {
					ports_debug yes
				} elseif {$c == "q"} {
					ports_quiet yes
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
	
	# target
	} elseif {[regexp {^([A-Za-z0-9\/\._\-]+)$} $arg match opt] == 1} {
		set target $opt

	} else {
		print_usage; exit
	}
}
dportinit
set workername [dportopen $portdir options variations]
set result [dportexec $workername $target]
dportclose $workername
return $result
