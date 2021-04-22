# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::random 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of a channel similar to
# Meta description Memchan's random channel. Based on Tcl
# Meta description 8.5's channel reflection support. Exports
# Meta description a single command for the creation of new
# Meta description channels. One argument, a list of
# Meta description numbers to initialize the feedback
# Meta description register of the internal random number
# Meta description generator. Result is the handle of the
# Meta description new channel.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::events
# Meta require {Tcl 8.5}
# @@ Meta End

# # ## ### ##### ######## #############

package require tcl::chan::events
package require Tcl 8.5
package require TclOO

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

proc ::tcl::chan::random {seed} {
    return [::chan create {read} [random::implementation new $seed]]
}

oo::class create ::tcl::chan::random::implementation {
    superclass tcl::chan::events ; # -> initialize, finalize, watch

    constructor {theseed} {
	my variable seed next
	set seed $theseed
	set next [expr "([join $seed +]) & 0xff"]
	next
    }

    method initialize {args} {
	my allow read
	next {*}$args
    }

    # Generate and return a block of N randomly selected bytes, as
    # requested. Random device.

    method read {c n} {
	set buffer {}
	while {$n} {
	    append buffer [binary format c [my Next]]
	    incr n -1
	}
	return $buffer
    }

    variable seed
    variable next

    method Next {} {
	my variable seed next
	set result $next
	set next [expr {(2*$next - [lindex $seed 0]) & 0xff}]
	set seed [linsert [lrange $seed 1 end] end $result]
	return $result
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::random 1
return
