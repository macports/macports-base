# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::rot 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of a rot
# Meta description encryption transformation. Based on Tcl
# Meta description 8.6's transformation reflection support.
# Meta description The key byte is
# Meta description configured at construction time. Exports
# Meta description a single command adding a new
# Meta description transformation of this type to a channel.
# Meta description Two arguments, the channel to extend,
# Meta description plus the key byte.
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

proc ::tcl::transform::rot {chan key} {
    ::chan push $chan [rot::implementation new $key]
}

oo::class create ::tcl::transform::rot::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    # This transformation is intended for streaming operation. Seeking
    # the channel while it is active may cause undesirable
    # output. Proper behaviour may require the destruction of the
    # transform before seeking.

    method write {c data} {
	return [my Rot $data $key]
    }

    method read {c data} {
	return [my Rot $data $ikey]
    }

    # # ## ### ##### ######## #############

    constructor {thekey} {
	set key [expr {$thekey % 26}]
	set ikey [expr {26 - $key}]
	return
    }

    # # ## ### ##### ######## #############

    variable key ikey

    # # ## ### ##### ######## #############

    method Rot {data key} {
	# rot'ation is done byte-wise. Note that we are having binary
	# data at this point, making it necessary to convert into
	# numbers (scan), and back (binary format).

	set result {}
	foreach d [split $data {}] {
	    set dx [scan $d %c]
	    if {(65 <= $dx)  && ($dx <= 90)} {
		set n [binary format c \
			   [expr { (($dx - 65 + $key) % 26) + 65 }]]
	    } elseif {(97 <= $dx) && ($dx <= 122)} {
		set n [binary format c \
			   [expr { (($dx - 97 + $key) % 26) + 97 }]]
	    } else {
		set n $d
	    }

	    append result $n
		
	}
	return $result
    }
}

# # ## ### ##### ######## #############
package provide tcl::transform::rot 1
return
