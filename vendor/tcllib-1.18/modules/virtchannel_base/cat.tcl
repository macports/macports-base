# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2011 Andreas Kupries

# Facade concatenating the contents of the channels it was constructed
# with. Owns the sub-ordinate channels and closes them on exhaustion and/or
# when closed itself.

# @@ Meta Begin
# Package tcl::chan::cat 1.0.1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2011
# Meta as::license BSD
# Meta description Facade concatenating the contents of the channels it
# Meta description was constructed with. Owns the sub-ordinate channels
# Meta description and closes them on exhaustion and/or when closed itself.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::core
# Meta require {Tcl 8.5}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.5
package require TclOO
package require tcl::chan::core

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

proc ::tcl::chan::cat {args} {
    return [::chan create {read} [cat::implementation new {*}$args]]
}

oo::class create ::tcl::chan::cat::implementation {
    superclass ::tcl::chan::core ; # -> initialize, finalize.

    # We are not using the standard event handling class, because here
    # it will not be timer-driven. We propagate anything related to
    # events to catin and catout instead and let them handle things.

    constructor {args} {
	set channels $args
	# Disable encoding and translation processing in the wrapped channels.
	# This will happen in our generic layer instead.
	foreach c $channels {
	    fconfigure $c -translation binary
	    fconfigure $c -translation binary
	}
	set delay 10
	set watching 0
	return
    }

    destructor {
	foreach c $channels {
	    ::close $c
	}
	return
    }

    variable channels timer delay watching

    method watch {c requestmask} {
	if {"read" in $requestmask} {
	    # Activate event handling.  Either drive an eof home via
	    # timers, or activate things in the foremost sub-ordinate.

	    set watching 1
	    if {![llength $channels]} {
		set timer [after $delay \
			       [namespace code [list my Post $c]]]
	    } else {
		set c [lindex $channels 0]
		fileevent readable $c [list chan postevent $c read]
	    }
	} else {
	    # Stop events. Kill timer, or disable in the foremost
	    # sub-ordinate.

	    set watching 0
	    if {![llength $channels]} {
		catch { after cancel $timer }
	    } else {
		fileevent readable [lindex $channels 0] {}
	    }
	}
	return
    }

    method read {c n} {
	if {![llength $channels]} {
	    # Actually should be EOF signal.
	    return {}
	}

	set buf {}
	while {([string length $buf] < $n) &&
	       [llength $channels]} {

	    set in     [lindex $channels 0]
	    set toread [expr {$n - [string length $buf]}]
	    append buf [::read $in $toread]

	    if {[eof $in]} {
		close $in
		set channels [lrange $channels 1 end]

		# The close above also killed any fileevent handling
		# we might have attached to this channel. We may have
		# to update the settings (i.e. move to next channel,
		# or to timer-based, to drive the eof home).

		if {$watching} {
		    my watch $c read
		}
	    }
	}

	if {$buf eq {}} {
	    return -code error EAGAIN
	}

	return $buf
    }

    method Post {c} {
	set timer [after $delay \
		       [namespace code [list my Post $c]]]
	chan postevent $c read
	return
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::cat 1.0.2
return
