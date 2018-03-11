# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::chan::variable 1.0.2
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of a channel representing
# Meta description an in-memory read-write random-access
# Meta description file. Based on Tcl 8.5's channel reflection
# Meta description support. Exports a single command for the
# Meta description creation of new channels. No arguments.
# Meta description Result is the handle of the new channel.
# Meta description Similar to -> tcl::chan::memchan, except
# Meta description that the variable holding the content
# Meta description exists outside of the channel itself, in
# Meta description some namespace, and as such is not a part
# Meta description of the channel. Seekable beyond the end
# Meta description of the data, implies appending of 0x00
# Meta description bytes.
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

proc ::tcl::chan::variable {varname} {
    return [::chan create {read write} [variable::implementation new $varname]]
}

oo::class create ::tcl::chan::variable::implementation {
    superclass ::tcl::chan::events ; # -> initialize, finalize, watch

    constructor {thevarname} {
	set varname $thevarname
	set at 0

	upvar #0 $varname content
	if {![info exists content]} {
	    set content {}
	}
	next
    }

    method initialize {args} {
	my allow write
	my Events
	next {*}$args
    }

    variable varname at 

    method read {c n} {
	# Bring connected variable for content into scope.

	upvar #0 $varname content

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

    method write {c newbytes} {
	# Bring connected variable for content into scope.

	upvar #0 $varname content

	# Return immediately if there is nothing is to write.
	set n [string length $newbytes]
	if {$n == 0} {
	    return $n
	}

	# Determine where and how to write. There are three possible cases.
	# (1) Append at/after the end.
	# (2) Starting in the middle, but extending beyond the end.
	# (3) Replace in the middle.

	set max [string length $content]
	if {$at >= $max} {
	    # Ad 1.
	    append content $newbytes
	    set at [string length $content]
	} else {
	    set last [expr {$at + $n - 1}]
	    if {$last >= $max} {
		# Ad 2.
		set content [string replace $content $at end $newbytes]
		set at [string length $content]
	    } else {
		# Ad 3.
		set content [string replace $content $at $last $newbytes]
		set at $last
		incr at
	    }
	}

	my Events
	return $n
    }

    method seek {c offset base} {
	# offset == 0 && base == current
	# <=> Seek nothing relative to current
	# <=> Report current location.

	if {!$offset && ($base eq "current")} {
	    return $at
	}

	# Bring connected variable for content into scope.

	upvar #0 $varname content

	# Compute the new location per the arguments.

	set max [string length $content]
	switch -exact -- $base {
	    start   { set newloc $offset}
	    current { set newloc [expr {$at  + $offset    }] }
	    end     { set newloc [expr {$max + $offset - 1}] }
	}

	# Check if the new location is beyond the range given by the
	# content.

	if {$newloc < 0} {
	    return -code error "Cannot seek before the start of the channel"
	} elseif {$newloc >= $max} {
	    # We can seek beyond the end of the current contents, add
	    # a block of zeros.
	    append content [binary format @[expr {$newloc - $max}]]
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
package provide tcl::chan::variable 1.0.3
return
