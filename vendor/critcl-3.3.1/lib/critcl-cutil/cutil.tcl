## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
# Pragmas for MetaData Scanner.
# n/a

# CriTcl Utility Commands To Provide Common C-level utility functions.
#
# Copyright (c) 2017-2024 Andreas Kupries <andreas_kupries@users.sourceforge.net>

package provide critcl::cutil 0.5

# # ## ### ##### ######## ############# #####################
## Requirements.

package require Tcl    8.6 9   ; # Min supported version.
package require critcl 3.2

namespace eval ::critcl::cutil {}

# # ## ### ##### ######## ############# #####################
## Implementation -- API: Embed C Code

# # ## ### ##### ######## ############# #####################

proc critcl::cutil::alloc {} {
    variable selfdir
    critcl::cheaders -I$selfdir/allocs
    critcl::include critcl_alloc.h
    return
}

proc critcl::cutil::assertions {{enable 0}} {
    variable selfdir
    critcl::cheaders -I$selfdir/asserts
    critcl::include critcl_assert.h
    if {!$enable} return
    critcl::cflags -DCRITCL_ASSERT
    return
}

proc critcl::cutil::tracer {{enable 0}} {
    variable selfdir
    alloc ;# Tracer uses the allocation utilities in its implementation
    critcl::cheaders -I$selfdir/trace
    critcl::include  critcl_trace.h
    if {!$enable} return
    critcl::csources $selfdir/trace/trace.c
    critcl::cflags -DCRITCL_TRACER
    return
}

proc critcl::cutil::tracer-config {args} {
    while {[llength $args]} {
	set o [lindex $args 0]
	switch -exact -- $o {
	    -unthreaded -
	    -nothreads  {
		critcl::cflags -DCRITCL_TRACE_NOTHREADS
	    }
	    default {
		return -code error \
		    "Unknown option $o, expected -nothreads, or -unthreaded"
	    }
	}
    }
    return
}

# # ## ### ##### ######## ############# #####################
## State

namespace eval ::critcl::cutil {
    variable selfdir [file dirname [file normalize [info script]]]
}

# # ## ### ##### ######## ############# #####################
## Export API

namespace eval ::critcl::cutil {
    namespace export alloc assert tracer
    catch { namespace ensemble create }
}

# # ## ### ##### ######## ############# #####################
## Ready
return
