# # ## ### ##### ######## ############# #####################
## Copyright (c) 2013 Andreas Kupries, BSD licensed

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require fileutil ;# cat

# # ## ### ##### ######## ############# #####################
## API setup
#

namespace eval ::string::token {
    namespace export chomp file text
    namespace ensemble create
}

## NOTE: We are placing the 'token' ensemble command into the Tcl
##       core's builtin 'string' ensemble.

apply {{} {
    set map [namespace ensemble configure ::string -map]
    dict set map token ::string::token
    namespace ensemble configure ::string -map $map
    return
}}

# # ## ### ##### ######## ############# #####################
## API

proc ::string::token::file {map path args} {
    return [text $map [fileutil::cat {*}$args $path]]
}

proc ::string::token::text {map text} {
    # map = dict (regex -> label)
    #   note! order is important, most specific to most general.

    # result = list (token)
    # where
    #   token = list(label start-index end-index)

    set start  0
    set result {}

    # status values:
    #  0: no token found, abort
    #  1: token found, continue
    #  2: no token found, end of string reached, stop, ok.
    set status 1
    while {$status == 1} {
	set status [chomp $map start $text result]
    }
    if {$status == 0} {
	return -code error \
	    -errorcode {STRING TOKEN BAD CHARACTER} \
	    "Unexpected character '[string index $text $start]' at offset $start"
    }
    return $result
}

# # ## ### ##### ######## ############# #####################
## Internal, helpers.

proc ::string::token::chomp {map sv text rv} {
    upvar 1 $sv start $rv result

    # Stop when trying to match after the end of the string.
    if {$text eq {}} {return 2}
    if {$start >= [string length $text]} {return 2}

    #puts |$start||[string range $text $start end]||$result|

    foreach {pattern label} $map {
	if {![regexp -start $start -indices -- \\A($pattern) $text -> range]} continue

	lappend result [list $label {*}$range]
	lassign $range a e

	#puts MATCH|$pattern|[string range $text $a $e]|

	set start $e
	incr start
	return 1
    }
    return 0
}

# # ## ### ##### ######## ############# #####################
## Ready

package provide string::token 1
return
