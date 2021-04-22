# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::identity 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   The prototypical observer transformation.
# Meta as::notes   To observers what null is to reflected
# Meta as::notes   base channels. For other observers see
# Meta as::notes   adler32, crc32, counter, and observer
# Meta as::notes   (stream copy).
# Meta description Implementation of an identity
# Meta description transformation, i.e one which does not
# Meta description change the data in any way, shape, or
# Meta description form. Based on Tcl 8.6's transformation
# Meta description reflection support. Exports a single
# Meta description command adding a new transform of this
# Meta description type to a channel. One argument, the
# Meta description channel to extend. No result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::identity {chan} {
    ::chan push $chan [identity::implementation new]
}

oo::class create ::tcl::transform::identity::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    method write {c data} {
	return $data
    }

    method read {c data} {
	return $data
    }

    # No partial data, nor state => no flush, drain, nor clear needed.

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::transform::identity 1
return
