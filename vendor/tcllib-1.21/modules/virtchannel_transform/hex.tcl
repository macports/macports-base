# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::hex 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of a hex transformation,
# Meta description using Tcl 8.6's transformation
# Meta description reflection support. Uses the binary
# Meta description command to implement the transformation.
# Meta description Exports a single command adding a new
# Meta description transform of this type to a channel. One
# Meta description argument, the channel to extend. No
# Meta description result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::hex {chan} {
    ::chan push $chan [hex::implementation new]
    return
}

oo::class create ::tcl::transform::hex::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    method write {c data} {
	# bytes -> hex
	binary scan $data H* hex
	return $hex
    }

    method read {c data} {
	# hex -> bytes
	return [binary format H* $data]
    }

    # No partial data, nor state => no flush, drain, nor clear needed.

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::transform::hex 1
return
