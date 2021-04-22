# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2011,2019 Andreas Kupries

# Facade concatenating the contents of the channels it was constructed
# with. Owns the sub-ordinate channels and closes them on exhaustion and/or
# when closed itself.

# @@ Meta Begin
# Package tcl::chan::cat 1.0.3
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
	# Disable translation (and hence encoding) in the wrapped channels.
	# This will happen in our generic layer instead.
	foreach c $channels {
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
		set timer [after $delay [namespace code [list my Post $c]]]
	    } else {
		chan event [lindex $channels 0] readable [list chan postevent $c read]
	    }
	} else {
	    # Stop events. Either kill timer, or disable in the
	    # foremost sub-ordinate.

	    set watching 0
	    if {![llength $channels]} {
		catch { after cancel $timer }
	    } else {
		chan event [lindex $channels 0] readable {}
	    }
	}
	return
    }

    method read {c n} {
	if {![llength $channels]} {
	    # This signals EOF higher up.
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

		# The close of the exhausted subordinate killed any
		# fileevent handling we may have had attached to this
		# channel. Update the settings (i.e. move to the next
		# subordinate, or to timer-based, to drive the eof
		# home).

		if {$watching} {
		    my watch $c read
		}
	    }
	}

	# When `buf` is empty, all channels have been exhausted and
	# closed, therefore returning this empty string will cause an
	# EOF higher up.
	return $buf
    }

    method Post {c} {
	set timer [after $delay [namespace code [list my Post $c]]]
	chan postevent $c read
	return
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::cat 1.0.3
return
