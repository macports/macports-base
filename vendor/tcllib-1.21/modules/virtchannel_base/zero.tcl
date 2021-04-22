# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::zero 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Re-implementation of Memchan's zero
# Meta description channel. Based on Tcl 8.5's channel
# Meta description reflection support. Exports a single
# Meta description command for the creation of new
# Meta description channels. No arguments. Result is the
# Meta description handle of the new channel.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::events
# Meta require {Tcl 8.5}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.5
package require TclOO
package require tcl::chan::events

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

proc ::tcl::chan::zero {} {
    return [::chan create {read} [zero::implementation new]]
}

oo::class create ::tcl::chan::zero::implementation {
    superclass tcl::chan::events ; # -> initialize, finalize, watch

    method initialize {args} {
	my allow read
	next {*}$args
    }

    # Generate and return a block of N null bytes, as requested.
    # Zero device.

    method read {c n} {
	return [binary format @$n]
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::zero 1
return
