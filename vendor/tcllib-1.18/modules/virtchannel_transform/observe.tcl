# -*- tcl -*-
# # ## ### ##### ######## #############
# (C) 2009 Andreas Kupries

# @@ Meta Begin
# Package tcl::transform::observe 1
# Meta as::author {Andreas Kupries}
# Meta as::copyright 2009
# Meta as::license BSD
# Meta as::notes   For other observers see adler32, crc32,
# Meta as::notes   identity, and counter.
# Meta as::notes   Possibilities for extension: Save the
# Meta as::notes   observed bytes to variables instead of
# Meta as::notes   channels. Use callbacks to save the
# Meta as::notes   observed bytes.
# Meta description Implementation of an observer
# Meta description transformation copying the bytes going
# Meta description through it into two channels configured
# Meta description at construction time. Based on Tcl 8.6's
# Meta description transformation reflection support.
# Meta description Exports a single command adding a new
# Meta description transformation of this type to a channel.
# Meta description Three arguments, the channel to extend,
# Meta description plus the channels to write the bytes to.
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

proc ::tcl::transform::observe {chan logw logr} {
    ::chan push $chan [observe::implementation new $logw $logr]
}

oo::class create ::tcl::transform::observe::implementation {
    superclass tcl::transform::core ;# -> initialize, finalize, destructor

    method write {c data} {
	if {$logw ne {}} {
	    puts -nonewline $logw $data
	}
	return $data
    }

    method read {c data} {
	if {$logr ne {}} {
	    puts -nonewline $logr $data
	}
	return $data
    }

    # No partial data, nor state => no flush, drain, nor clear needed.

    # # ## ### ##### ######## #############

    constructor {lw lr} {
	set logr $lr
	set logw $lw
	return
    }

    # # ## ### ##### ######## #############

    variable logr logw

    # # ## ### ##### ######## #############
}

# # ## ### ##### ######## #############
package provide tcl::transform::observe 1
return
