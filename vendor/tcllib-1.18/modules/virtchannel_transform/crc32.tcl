# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::crc32 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   For other observers see adler32, counter,
# Meta as::notes   identity, and observer (stream copy).
# Meta description Implementation of a crc32 checksum
# Meta description transformation. Based on Tcl 8.6's
# Meta description transformation reflection support (TIP
# Meta description 230), and its zlib support (TIP 234) for
# Meta description the crc32 functionality. An observer
# Meta description instead of a transformation. For details
# Meta description on the crc checksum see
# Meta description http://en.wikipedia.org/wiki/Cyclic_redundancy_check#Commonly_used_and_standardised_CRCs .
# Meta description The observer saves the checksums into two
# Meta description namespaced external variables specified
# Meta description at construction time. Exports a single
# Meta description command adding a new transformation of
# Meta description this type to a channel. One argument,
# Meta description the channel to extend, plus options to
# Meta description specify the variables for the checksums.
# Meta description No result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::crc32 {chan args} {
    ::chan push $chan [crc32::implementation new {*}$args]
}

oo::class create ::tcl::transform::crc32::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    # This transformation continuously computes a checksum from the
    # data it sees. This data may be arbitrary parts of the input or
    # output if the channel is seeked while the transform is
    # active. This may not be what is wanted and the desired behaviour
    # may require the destruction of the transform before seeking.

    method write {c data} {
	my Crc32 -write-variable $data
	return $data
    }

    method read {c data} {
	my Crc32 -read-variable $data
	return $data
    }

    # # ## ### ##### ######## #############

    constructor {args} {
	array set options {
	    -read-variable  {}
	    -write-variable {}
	}
	# todo: validity checking of options (legal names, legal
	# values, etc.)
	array set options $args
	my Init -read-variable
	my Init -write-variable
	return
    }

    # # ## ### ##### ######## #############

    variable options

    # # ## ### ##### ######## #############

    method Init {o} {
	if {$options($o) eq ""} return
	upvar #0 $options($o) crc
	set crc 0
	return
    }

    method Crc32 {o data} {
	if {$options($o) eq ""} return
	upvar #0 $options($o) crc
	set crc [zlib crc32 $data $crc]
	return
    }
}

# # ## ### ##### ######## #############
package provide tcl::transform::crc32 1
return
