# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2011 Andreas Kupries

# Facade wrapping the separate channels for stdin and stdout into a
# single read/write channel for all regular standard i/o. Not
# seekable. Fileevent handling is propagated to the regular channels
# the facade wrapped about. Only one instance of the class is
# ever created.

# @@ Meta Begin
# Package tcl::chan::std 1.0.1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2011
# Meta as::license BSD
# Meta description Facade wrapping the separate channels for stdin
# Meta description and stdout into a single read/write channel for
# Meta description all regular standard i/o. Not seekable. Only one
# Meta description instance of the class is ever created.
# Meta platform tcl
# Meta require TclOO
# Meta require tcl::chan::core
# Meta require {Tcl 8.5}
# @@ Meta End

# # ## ### ##### ######## #############

package require Tcl 8.5
package require TclOO
package require tcl::chan::core

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {}

proc ::tcl::chan::std {} {
    ::variable std
    if {$std eq {}} {
	set std [::chan create {read write} [std::implementation new]]
    }
    return $std
}

oo::class create ::tcl::chan::std::implementation {
    superclass ::tcl::chan::core ; # -> initialize, finalize.

    # We are not using the standard event handling class, because here
    # it will not be timer-driven. We propagate anything related to
    # events to stdin and stdout instead and let them handle things.

    constructor {} {
	# Disable encoding and translation processing in the wrapped channels.
	# This will happen in our generic layer instead.
	fconfigure stdin  -translation binary
	fconfigure stdout -translation binary
	return
    }

    method watch {c requestmask} {

	if {"read" in $requestmask} {
	    fileevent readable stdin [list chan postevent $c read]
	} else {
	    fileevent readable stdin {}
	}

	if {"write" in $requestmask} {
	    fileevent readable stdin [list chan postevent $c write]
	} else {
	    fileevent readable stdout {}
	}

	return
    }

    method read {c n} {
	# Read is redirected to stdin.
	return [::read stdin $n]
    }

    method write {c newbytes} {
	# Write is redirected to stdout.
	puts -nonewline stdout $newbytes
	flush stdout
	return [string length $newbytes]
    }
}

# # ## ### ##### ######## #############

namespace eval ::tcl::chan {
    ::variable std {}
}

# # ## ### ##### ######## #############
package provide tcl::chan::std 1.0.1
return
