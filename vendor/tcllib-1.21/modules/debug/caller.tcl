## -*- tcl -*-
# ### ### ### ######### ######### #########

## Utility command for use as debug prefix command to un-mangle snit
## and TclOO method calls.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5
package require debug

namespace eval ::debug {
    namespace export caller
    namespace ensemble create
}

# ### ### ### ######### ######### #########
## API & Implementation

proc ::debug::caller {args} {
    # For snit (type)methods, rework the command line to be more
    # legible and in line with what the user would expect. To this end
    # we pull the primary command out of the arguments, be it type or
    # object, massage the command to match the original (type)method
    # name, then resort and expand the words to match the call before
    # the snit got its claws into it.

    set a [lassign [info level -1] m]
    regsub {.*Snit_} $m {} m

    if {[string match ::oo::Obj*::my $m]} {
	# TclOO call.
	set m [uplevel 1 self]
	return [list $m {*}[Filter $a $args]]
    }
    if {$m eq "my"} {
	# TclOO call.
	set m [uplevel 1 self]
	return [list $m {*}[Filter $a $args]]
    }

    switch -glob -- $m {
	htypemethod* {
	    # primary = type, a = type
	    set a [lassign $a primary]
	    set m [string map {_ { }} [string range $m 11 end]]
	}
	typemethod* {
	    # primary = type, a = type
	    set a [lassign $a primary]
	    set m [string range $m 10 end]
	}
	hmethod* {
	    # primary = self, a = type selfns self win ...
	    set a [lassign $a _ _ primary _]
	    set m [string map {_ { }} [string range $m 7 end]]
	}
	method* {
	    # primary = self, a = type selfns self win ...
	    set a [lassign $a _ _ primary _]
	    set m [string range $m 6 end]
	}
	destructor -
	constructor {
	    # primary = self, a = type selfns self win ...
	    set a [lassign $a _ _ primary _]
	}
	typeconstructor {
	    return [list {*}$a $m]
	}
	default {
	    # Unknown
	    return [list $m {*}[Filter $a $args]]
	}
    }
    return [list $primary {*}$m {*}[Filter $a $args]]
}

proc ::debug::Filter {args droplist} {
    if {[llength $droplist]} {
	# Replace unwanted arguments with '*'. This is usually done
	# for arguments which can be large Tcl values. These would
	# screw up formatting and, to add insult to this injury, also
	# repeat for each debug output in the same proc, method, etc.
	foreach i [lsort -integer $droplist] {
	    set args [lreplace $args $i $i *]
	}
    }
    return $args
}

# ### ######### ###########################
## Ready for use

package provide debug::caller 1.1
return
