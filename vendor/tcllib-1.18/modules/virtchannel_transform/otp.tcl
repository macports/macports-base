# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::otp 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta description Implementation of an onetimepad
# Meta description encryption transformation. Based on Tcl
# Meta description 8.6's transformation reflection support.
# Meta description The key bytes are read from two channels
# Meta description configured at construction time. Exports
# Meta description a single command adding a new
# Meta description transformation of this type to a channel.
# Meta description Three arguments, the channel to extend,
# Meta description plus the channels to read the keys from.
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

proc ::tcl::transform::otp {chan keychanw keychanr} {
    ::chan push $chan [otp::implementation new $keychanw $keychanr]
}

oo::class create ::tcl::transform::otp::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    # This transformation is intended for streaming operation. Seeking
    # the channel while it is active may cause undesirable
    # output. Proper behaviour may require the destruction of the
    # transform before seeking.

    method write {c data} {
	return [my Xor $data $keychanw]
    }

    method read {c data} {
	return [my Xor $data $keychanr]
    }

    # # ## ### ##### ######## #############

    constructor {keyw keyr} {
	set keychanr $keyr
	set keychanw $keyw
	return
    }

    # # ## ### ##### ######## #############

    variable keychanr keychanw

    # # ## ### ##### ######## #############

    # A very convoluted way to perform the XOR would be to use TIP
    # #317's hex encoding to convert the bytes into strings, then zip
    # key and data into an interleaved string (nibble wise), then
    # perform the xor as a 'string map' of the whole thing, and at
    # last 'binary decode hex' the string back into bytes. Even so
    # most ops would run on the whole message at C level. Except for
    # the interleave. :(

    method Xor {data keychan} {
	# xor is done byte-wise. to keep IO down we read the key bytes
	# once, before the loop handling the bytes. Note that we are
	# having binary data at this point, making it necessary to
	# convert into numbers (scan), and back (binary format).

	set keys [read $keychan [string length $data]]
	set result {}
	foreach d [split $data {}] k [split $keys {}] {
	    append result \
		[binary format c \
		     [expr {
			    [scan $d %c] ^
			    [scan $k %c]
			}]]
	}
	return $result
    }
}

# # ## ### ##### ######## #############
package provide tcl::transform::otp 1
return
