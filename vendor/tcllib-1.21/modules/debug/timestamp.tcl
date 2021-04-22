# -*- tcl -*
# Debug -- Timestamps.
# -- Colin McCormack / originally Wub server utilities
#
# Generate timestamps for debug messages.
# The provided commands are for use in prefixes and headers.

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug

namespace eval ::debug {
    namespace export timestamp
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################
## API & Implementation

proc ::debug::timestamp {} {
    variable timestamp::delta
    variable timestamp::baseline

    set now [::tcl::clock::milliseconds]
    if {$delta} {
	set time "${now}-[expr {$now - $delta}]mS "
    } else {
	set time "${now}mS "
    }
    set delta $now
    return $time
}

# # ## ### ##### ######## ############# #####################

namespace eval ::debug::timestamp {
    variable delta    0
    variable baseline [::tcl::clock::milliseconds]
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide debug::timestamp 1
return
