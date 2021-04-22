# # ## ### ##### ######## ############# ######################
## Verify VISA credit card number
#
## Reference
##	http://wiki.cdyne.com/wiki/index.php?title=Credit_Card_Verification
##	http://www.beachnet.com/~hstiles/cardtype.html

# # ## ### ##### ######## ############# ######################

# The code below implements the interface of a snit validation type,
# making it directly usable with snit's -type option in option
# specifications.

# # ## ### ##### ######## ############# ######################
## Requisites

package require Tcl 8.5
package require snit
package require valtype::luhn
package require valtype::common

# # ## ### ##### ######## ############# ######################
## Implementation

namespace eval ::valtype::creditcard::visa {
    namespace import ::valtype::common::*
}

snit::type ::valtype::creditcard::visa {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {[string length $value] ni {13 16}} {
	    badlength {CREDITCARD VISA} {13 16} "CREDITCARD VISA number"
	} elseif {[string index $value 0] ne "4"} {
	    badprefix {CREDITCARD VISA} 4 "CREDITCARD VISA number"
	}

	return [valtype::luhn validate $value {CREDITCARD VISA}]
    }

    typemethod checkdigit {value} {
	if {[string length $value] ni {12 15}} {
	    badlength {CREDITCARD VISA} {12 15} "CREDITCARD VISA number without checkdigit"
	} elseif {[string index $value 0] ne "4"} {
	    badprefix {CREDITCARD VISA} 4 "CREDITCARD VISA number without checkdigit"
	}

	return [valtype::luhn checkdigit $value {CREDITCARD VISA}]
    }

    #-------------------------------------------------------------------
    # Constructor

    # None needed; no options

    #-------------------------------------------------------------------
    # Public Methods

    method validate {value} {
        $type validate $value
    }
}

# # ## ### ##### ######## ############# ######################
## Ready

package provide valtype::creditcard::visa 1
