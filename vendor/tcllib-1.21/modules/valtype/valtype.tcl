# # ## ### ##### ######## ############# ######################
## (C) 2011 Andreas Kupries. BSD licensed.
#
## Common helper commands for the validation types in this
## module.

# # ## ### ##### ######## ############# ######################

# # ## ### ##### ######## ############# ######################
## Requisites

package require Tcl 8.5
namespace eval ::valtype::common {}

# # ## ### ##### ######## ############# ######################
## Implementation

proc ::valtype::common::reject {code text} {
    if {[string match {[aeiouAEIOU]*} $text]} {
	set prefix "Not an "
    } else {
	set prefix "Not a "
    }

    return -code error \
	-errorcode [list INVALID {*}$code] \
	$prefix$text
}

proc ::valtype::common::badchar {code {text {}}} {
    reject [list {*}$code CHAR] $text
}

proc ::valtype::common::badcheck {code {text {}}} {
    if {$text ne {}} { append text ", " }
    append text "the check digit is incorrect"
    reject [list {*}$code CHECK-DIGIT] $text
}

proc ::valtype::common::badlength {code lengths {text {}}} {
    set ln [llength $lengths]
    if {$text ne {}} { append text ", " }
    append text "incorrect length"
    if {$ln} {
	if {$ln == 1} {
	    append text ", expected [lindex $lengths 0] characters"
	} else {
	    append text ", expected one of [linsert [join $lengths {, }] end-1 or] characters"
	}
    }
    reject [list {*}$code LENGTH] $text
}

proc ::valtype::common::badprefix {code prefixes {text {}}} {
    set ln [llength $prefixes]
    if {$text ne {}} { append text ", " }
    append text "incorrect prefix"
    if {$ln} {
	if {$ln == 1} {
	    append text ", expected [lindex $prefixes 0]"
	} else {
	    append text ", expected one of [linsert [join $prefixes {, }] end-1 or]"
	}
    }
    reject [list {*}$code PREFIX] $text
}

# # ## ### ##### ######## ############# ######################

namespace eval ::valtype::common {
    namespace export reject badchar badcheck badlength badprefix
}

# # ## ### ##### ######## ############# ######################
## Ready

package provide valtype::common 1
