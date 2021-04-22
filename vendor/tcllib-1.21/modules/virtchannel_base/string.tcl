# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::string 1.0.3
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of a channel representing
# Meta description an in-memory read-only random-access
# Meta description file. Based on using Tcl 8.5's channel
# Meta description reflection support. Exports a single
# Meta description command for the creation of new channels.
# Meta description One argument, the contents of the file.
# Meta description Result is the  handle of the new channel.
# Meta description Similar to -> tcl::chan::memchan, except
# Meta description that the content is read-only. Seekable
# Meta description only within the bounds of the content.
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

proc ::tcl::chan::string {content} {
    return [::chan create {read} [string::implementation new $content]]
}

oo::class create ::tcl::chan::string::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    constructor {thecontent} {
	set content $thecontent
	set at 0
	next
    }

    method initialize {args} {
	my Events
	next {*}$args
    }

    variable content at 

    method read {c n} {

	# First determine the location of the last byte to read,
	# relative to the current location, and limited by the maximum
	# location we are allowed to access per the size of the
	# content.

	set last [expr {min($at + $n,[string length $content])-1}]

	# Then extract the relevant range from the content, move the
	# seek location behind it, and return the extracted range. Not
	# to forget, switch readable events based on the seek
	# location.

	set res [string range $content $at $last]
	set at $last
	incr at

	my Events
	return $res
    }

    method seek {c offset base} {
	# offset == 0 && base == current
	# <=> Seek nothing relative to current
	# <=> Report current location.

	if {!$offset && ($base eq "current")} {
	    return $at
	}

	# Compute the new location per the arguments.

	set max [string length $content]
	switch -exact -- $base {
	    start   { set newloc $offset}
	    current { set newloc [expr {$at  + $offset }] }
	    end     { set newloc [expr {$max + $offset }] }
	}

	# Check if the new location is beyond the range given by the
	# content.

	if {$newloc < 0} {
	    return -code error "Cannot seek before the start of the channel"
	} elseif {$newloc > $max} {
	    return -code error "Cannot seek after the end of the channel"
	}

	# Commit to new location, switch readable events, and report.
	set at $newloc

	my Events
	return $at
    }

    method Events {} {
	# Always readable -- Even if the seek location is at the end
	# (or beyond).  In that case the readable events are fired
	# endlessly until the eof indicated by the seek location is
	# properly processed by the event handler. Like for regular
	# files -- Ticket [864a0c83e3].
	my allow read
    }
}

# # ## ### ##### ######## #############
package provide tcl::chan::string 1.0.3
return
