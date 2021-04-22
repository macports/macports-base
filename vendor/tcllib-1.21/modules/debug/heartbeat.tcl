# -*- tcl -*
# Debug -- Heartbeat. Track operation of Tcl's eventloop.
# -- Colin McCormack / originally Wub server utilities

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug

namespace eval ::debug {
    namespace export heartbeat
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################
## API & Implementation

proc ::debug::heartbeat {{delta 500}} {
    variable duration $delta
    variable timer

    if {$duration > 0} {
	# stop a previous heartbeat before starting the next
	catch { after cancel $timer }
	on heartbeat
	::debug::every $duration {
	    debug.heartbeat {[::debug::pulse]}
	}
    } else {
	catch { after cancel $timer }
	off heartbeat
    }
}

proc ::debug::every {ms body} {
    eval $body
    variable timer [after $ms [info level 0]]
    return
}

proc ::debug::pulse {} {
    variable duration
    variable hbtimer
    variable heartbeat

    set now  [::tcl::clock::milliseconds]
    set diff [expr {$now - $hbtimer - $duration}]

    set hbtimer $now

    return [list [incr heartbeat] $diff]
}

# # ## ### ##### ######## ############# #####################

namespace eval ::debug {
    variable duration  0 ; # milliseconds between heart-beats
    variable heartbeat 0 ; # beat counter
    variable hbtimer   [::tcl::clock::milliseconds]
    variable timer
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide debug::heartbeat 1.0.1
return
