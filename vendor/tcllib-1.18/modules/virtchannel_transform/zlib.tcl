# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::zlib 1.0.1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   Possibilities for extension: Currently
# Meta as::notes   the mapping between read/write and
# Meta as::notes   de/compression is fixed. Allow it to be
# Meta as::notes   configured at construction time.
# Meta description Implementation of a zlib (de)compressor.
# Meta description Based on Tcl 8.6's transformation
# Meta description reflection support (TIP 230) and zlib
# Meta description support (TIP 234). Compresses on write.
# Meta description Exports a single command adding a new
# Meta description transformation of this type to a channel.
# Meta description Two arguments, the channel to extend,
# Meta description and the compression level. No result.
# Meta platform tcl
# Meta require tcl::transform::core
# Meta require {Tcl 8.6}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.6
package require tcl::transform::core

# # ## ### ##### ######## #############

namespace eval ::tcl::transform {}

proc ::tcl::transform::zlib {chan {level 4}} {
    ::chan push $chan [zlib::implementation new $level]
    return
}

oo::class create ::tcl::transform::zlib::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    # This transformation is intended for streaming operation. Seeking
    # the channel while it is active may cause undesirable
    # output. Proper behaviour may require the destruction of the
    # transform before seeking.

    method initialize {c mode} {
	set compressor   [zlib stream deflate -level $level]
	set decompressor [zlib stream inflate]

	next $c $mode
    }

    method finalize {c} {
	$compressor   close
	$decompressor close

	next $c
    }

    method write {c data} {
	$compressor put $data
	return [$compressor get]
    }

    method read {c data} {
	$decompressor put $data
	return [$decompressor get]
    }

    method flush {c} {
	$compressor flush
	return [$compressor get]
    }

    method drain {c} {
	$decompressor flush
	return [$decompressor get]
    }

    # # ## ### ##### ######## #############

    constructor {thelevel} {
	# Should validate input (level in (0 ...9))
	set level $thelevel
	return
    }

    # # ## ### ##### ######## #############

    variable level compressor decompressor

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::transform::zlib 1.0.1
return
