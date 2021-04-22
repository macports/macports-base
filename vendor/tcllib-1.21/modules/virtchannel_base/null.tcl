# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::null 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Re-implementation of Memchan's null
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

proc ::tcl::chan::null {} {
    return [::chan create {write} [null::implementation new]]
}

oo::class create ::tcl::chan::null::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    method initialize {args} {
	my allow write
	next {*}$args
    }

    # Ignore the data in most particulars. We do count it so that we
    # can tell the caller that everything was written. Null device.

    method write {c data} {
	return [string length $data]
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::null 1
return
