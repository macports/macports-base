#!@TCLSH@
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

# UI Instantiations
# ui_options(ports_debug) - If set, output debugging messages.
# ui_options(ports_verbose) - If set, output info messages (ui_info)
# ui_options(ports_quiet) - If set, don't output "standard messages"

# ui_options accessor
proc ui_isset {val} {
    global ui_options
    if {[info exists ui_options($val)]} {
	if {$ui_options($val) == "yes"} {
	    return 1
	}
    }
    return 0
}

# UI Callback

proc ui_puts {messagelist} {
    set channel stdout
    array set message $messagelist
    switch $message(priority) {
        debug {
            if {[ui_isset ports_debug]} {
                set channel stderr
                set str "DEBUG: $message(data)"
            } else {
                return
            }
        }
        info {
            if {![ui_isset ports_verbose]} {
                return
            }
	    set str $message(data)
        }
        msg {
            if {[ui_isset ports_quiet]} {
                return
            }
	    set str $message(data)
        }
        error {
            set str "Error: $message(data)"
            set channel stderr
        }
        warn {
            set str "Warning: $message(data)"
        }
    }
    puts $channel $str
}

# Standard procedures
proc print_usage args {
    global argv0
    puts "Usage: $argv0 \[-vdqof\] \[action\] \[-D portdir\] \[options\]"
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
		    set ui_options(ports_verbose) yes
		} elseif {$c == "f"} {
		    set options(ports_force) yes
		} elseif {$c == "d"} {
		    set ui_options(ports_debug) yes
		    # debug infers verbose
		    set ui_options(ports_verbose) yes
		} elseif {$c == "q"} {
		    set ui_options(ports_quiet) yes
		    set ui_options(ports_verbose) no
		    set ui_options(ports_debug) no
		} elseif {$c == "o"} {
		    set options(ports_ignore_older) yes
		} elseif {$opt == "D"} {
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
    } elseif {[regexp {^([A-Za-z0-9/._\-^$ \[\[?\(\)\\|\+\*]+)$} $arg match opt] == 1} {
	if {[info exists action]} {
	    set portname $opt
	} else {
	    set action $opt
	}
    } else {
	print_usage; exit
    }
}

if {![info exists action]} {
    set action build
}

if {$action == "list"} {
    set action search
    set portname .+
}

if {[catch {dportinit} result]} {
    puts "Failed to initialize ports system, $result"
    exit 1
}

switch -- $action {
    deps {
        set nodeps true

        # make sure a port was given on the command line
        if {![info exists portname]} {
	    puts "You must specify a port"
	    exit 1
        }

        # search for port
        if {[catch {dportsearch ^$portname$} result]} {
	    puts "port search failed: $result"
	    exit 1
        }

        if {$result == ""} {
            puts "No port $portname found."
	    exit 1
        }

        array set portinfo [lindex $result 1]

        # find build dependencies
        if {[info exists portinfo(depends_build)]} {
            puts "$portname has build dependencies on:"
            foreach i $portinfo(depends_build) {
                puts "\t[lindex [split [lindex $i 0] :] 2]"
            }
            set nodeps false
        }

        # find library dependencies
        if {[info exists portinfo(depends_lib)]} {
            puts "$portname has library dependencies on:"
            foreach i $portinfo(depends_lib) {
                puts "\t[lindex [split [lindex $i 0] :] 2]"
            }
            set nodeps false
        }

        # find runtime dependencies
        if {[info exists portinfo(depends_run)]} {
            puts "$portname has runtime dependencies on:"
            foreach i $portinfo(depends_run) {
                puts "\t[lindex [split [lindex $i 0] :] 2]"
            }
            set nodeps false
        }

        # no dependencies found
        if {$nodeps == "true"} {
            puts "$portname has no dependencies"
        }
    }
    installed {
        if {[catch {dportregistry::listinstalled} result]} {
            puts "Port failed: $result"
	    exit 1
        }
    }
    variants {
        # make sure a port was given on the command line
        if {![info exists portname]} {
	    puts "You must specify a port"
	    exit 1
        }
	
        # search for port
        if {[catch {dportsearch ^$portname$} result]} {
	    puts "port search failed: $result"
	    exit 1
        }
	
        if {$result == ""} {
            puts "No port $portname found."
        }
	
        array set portinfo [lindex $result 1]
	
        # if this fails the port doesn't have any variants
        if {![info exists portinfo(variants)]} {
            puts "$portname has no variants"
        } else {
	    # print out all the variants
            for {set i 0} {$i < [llength $portinfo(variants)]} {incr i} {
                puts "[lindex $portinfo(variants) $i]"
            }
        }
    }
    contents {
        # make sure a port was given on the command line
        if {![info exists portname]} {
	    puts "You must specify a port"
	    exit 1
        }
	
        set rfile [dportregistry::exists $portname]
        if {$rfile != ""} {
            if {[file extension $rfile] == ".bz2"} {
                set shortname [file rootname [file tail $rfile]]
                set fd [open "|bzcat -q $rfile" r]
            } else {
                set shortname [file tail $rfile]
                set fd [open $rfile r]
            }
	    
            while {-1 < [gets $fd line]} {
                set match [regexp {^contents \{(.*)\}$} $line dummy contents]
                if {$match == 1} {
		    puts "Contents of $shortname"
		    foreach f $contents {
			puts "\t[lindex $f 0]"
		    }
                    break
                }
            }
	    
            if {$match == 0} {
                puts "No contents list for $shortname"
		exit 1
            }
	    
            # kind of a corner case but I ran into it testing
            if {[catch {close $fd} result]} {
                puts "Port failed: $rfile may be corrupted"
                exit 1
            }
        } else {
            puts "Contents listing failed - no registry entry"
	    exit 1
        }
    }
    search {
	if {![info exists portname]} {
	    puts "You must specify a search pattern"
	    exit 1
	}
	if {[catch {set res [dportsearch $portname]} result]} {
	    puts "port search failed: $result"
	    exit 1
	}
	foreach {name array} $res {
	    array set portinfo $array
	    
	    # XXX is this the right place to verify an entry?
	    if {![info exists portinfo(name)]} {
		puts "Invalid port entry, missing portname"
		continue
	    }
	    if {![info exists portinfo(description)]} {
		puts "Invalid port entry for $portinfo(name), missing description"
		continue
	    }
	    if {![info exists portinfo(version)]} {
		puts "Invalid port entry for $portinfo(name), missing version"
		continue
	    }
	    if {![info exists portinfo(portdir)]} {
	        set output [format "%-20s\t%-8s\t%s" $portinfo(name) $portinfo(version) $portinfo(description)]
	    } else {
	        set output [format "%-8s\t%-14s\t%-8s\t%s" $portinfo(name) $portinfo(portdir) $portinfo(version) $portinfo(description)]
	    }
	    set portfound 1
	    puts $output
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
	    # Escape regex special characters
	    regsub -all "(\\(){1}|(\\)){1}|(\\{1}){1}|(\\+){1}|(\\{1}){1}|(\\{){1}|(\\}){1}|(\\^){1}|(\\$){1}|(\\.){1}|(\\\\){1}" $portname "\\\\&" search_string
	    if {[catch {set res [dportsearch ^$search_string\$]} result]} {
	    	puts "port search failed: $result"
		exit 1
	    }
	    if {[llength $res] < 2} {
		puts "Port $portname not found"
		exit 1
	    }
	    array set portinfo [lindex $res 1]
	    set porturl $portinfo(porturl)
	}
	if {![info exists porturl]} {
	    set porturl file://./
	}
	if {[catch {set workername [dportopen $porturl [array get options] [array get variations]]} result]} {
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
