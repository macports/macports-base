#!/usr/bin/env tclsh
# Traverse through all ports running the supplied target.  If target is
# "index" then just print some useful information about each port.

package require darwinports
dportinit
package require Pextlib

global target

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

# Output string "str"
# If you don't want newlines to be output, you must pass "-nonewline"
# as the second argument.

proc ui_puts {priority str nonl} {
    set channel stdout
    switch $priority {
        debug {
            if [ui_isset ports_debug] {
                set channel stderr
                set str "DEBUG: $str"
            } else {
                return
            }
        }
        info {
            if ![ui_isset ports_verbose] {
                return
            }
        }
        msg {
            if [ui_isset ports_quiet] {
                return
            }
        }
        error {
            set str "Error: $str"
            set channel stderr
        }
        warn {
            set str "Warning: $str"
        }
    }
    if {$nonl == "-nonewline"} {
	puts -nonewline $channel "$str"
	flush $channel 
    } else {
	puts "$str"
    }
}

# Get a line of input from the user and store in str, returning the
# number of bytes input.
proc ui_gets {str} {
    upvar $str in_string
    gets stdin in_string
}

# Ask a boolean "yes/no" question of the user, using "promptstr" as
# the prompt.  It should contain a trailing space and/or anything else
# you want to precede the user's input string.  Returns 1 for "yes" or
# 0 for "no".  This implementation also assumes an english yes/no or
# y/n response, but that is not mandated by the spec.  If "defvalue"
# is passed, it will be used as the default value if none is supplied
# by the user.
proc ui_yesno {promptstr {defvalue ""}} {
    set satisfaction no
    while {$satisfaction == "no"} {
	ui_puts $promptstr -nonewline
	if {[ui_gets mystr] == 0} {
	    if {[string length $defvalue] > 0} {
		set mystr $defvalue
	    } else {
		continue
	    }
	}
	if {[string compare -nocase -length 1 $mystr y] == 0} {
	    set rval 1
	    set satisfaction yes
	} elseif {[string compare -nocase -length 1 $mystr n] == 0} {
	    set rval 0
	    set satisfaction yes
	}
    }
    return $rval
}

# Put up a simple confirmation dialog, requesting nothing more than
# the user's acknowledgement of the prompt string passed in
# "promptstr".  There is no return value.
proc ui_confirm {promptstr} {
    ui_puts "$promptstr" -nonewline
    ui_gets garbagestr
}

# Display the contents of a file, ideally in a manner which allows the
# user to scroll through and read it comfortably (e.g. a license
# text).  For the "simple UI" version of this, we simply punt this to
# less(1) since rewriting a complete pager for the simple case would
# be a waste of time.  It's expected in a more complex UI case, a
# scrolling display widget of some type will be used.
proc ui_display {filename} {
    if [file exists $filename] {
	system "/usr/bin/less $filename"
    }
}

proc port_traverse {func {dir .}} {
    set pwd [pwd]
    if [catch {cd $dir} err] {
	ui_error $err
	return
    }
    foreach name [readdir .] {
	if {[string match $name .] || [string match $name ..]} {
	    continue
	}
	if [file isdirectory $name] {
	    port_traverse $func $name
	} else {
	    if [string match $name Portfile] {
		catch {eval $func {[file join $pwd $dir]}}
	    }
	}
    }
    cd $pwd
}

proc pindex {portdir} {
    global target options variations

    if [catch {set interp [dportopen file://$portdir [array get options] [array get variations]]} err] {
	puts "Error: Couldn't create interpreter for $portdir: $err"
	return -1
    }
    array set portinfo [dportinfo $interp]
    dportexec $interp $target
    dportclose $interp
}

# Main

# zero-out the options array
array set options [list]
array set variations [list]

if { $argc < 1 } {
    set target build
} else {
    for {set i 0} {$i < $argc} {incr i} {
	set arg [lindex $argv $i]

	if {[regexp {([A-Za-z0-9_\.]+)=(.*)} $arg match key val] == 1} {
	    # option=value
	    set options($key) \"$val\"
	} elseif {[regexp {^([-+])([-A-Za-z0-9_+\.]+)$} $arg match sign opt] == 1} {
	    # if +xyz -xyz or after the separator
	    set variations($opt) $sign
	} else {
	    set target $arg
	}
    }
}

if [file isdirectory dports] {
    port_traverse pindex dports
} elseif [file isdirectory ../dports] {
    port_traverse pindex .
} else {
    puts "Please run me from the darwinports directory (dports/..)"
    return 1
}
