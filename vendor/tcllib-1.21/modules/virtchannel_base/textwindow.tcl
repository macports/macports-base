# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::textwindow 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::credit  To Bryan Oakley for rotext, see
# Meta as::credit  http://wiki.tcl.tk/22036. His code was
# Meta as::credit  used here as template for the text
# Meta as::credit  widget portions of the channel.
# Meta description Implementation of a text window
# Meta description channel, using Tcl 8.5's channel
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

proc ::tcl::chan::textwindow {w} {
    set chan [::chan create {write} [textwindow::implementation new $w]]
    fconfigure $chan -encoding utf-8 -buffering none
    return $chan
}

oo::class create ::tcl::chan::textwindow::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    constructor {w} {
	set widget $w
	next
    }

    # # ## ### ##### ######## #############

    variable widget

    # # ## ### ##### ######## #############

    method initialize {args} {
	my allow write
	next {*}$args
    }

    method write {c data} {
	# NOTE: How is encoding convertfrom dealing with a partial
	# utf-8 character at the end of the buffer ? Should be saved
	# up for the next buffer. No idea if we can.

	$widget insert end [encoding convertfrom utf-8 $data]
	$widget see end
	return [string length $data]
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::textwindow 1
return
