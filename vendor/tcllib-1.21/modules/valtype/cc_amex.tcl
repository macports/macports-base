# # ## ### ##### ######## ############# ######################
## Verify AMEX credit card number
#
## Reference
##	http://wiki.cdyne.com/wiki/index.php?title=Credit_Card_Verification

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

namespace eval ::valtype::creditcard::amex {
    namespace import ::valtype::common::*
}

snit::type ::valtype::creditcard::amex {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {[string length $value] != 15} {
	    badlength {CREDITCARD AMEX} 15 "CREDITCARD AMEX number"
	} elseif {[string range $value 0 1] ni {34 37}} {
	    badprefix {CREDITCARD AMEX} {34 37} "CREDITCARD AMEX number"
	}

	return [valtype::luhn validate $value {CREDITCARD AMEX}]
    }

    typemethod checkdigit {value} {
	if {[string length $value] != 14} {
	    badlength {CREDITCARD AMEX} 14 "CREDITCARD AMEX number without checkdigit"
	} elseif {[string range $value 0 1] ni {34 37}} {
	    badprefix {CREDITCARD AMEX} {34 37} "CREDITCARD AMEX number without checkdigit"
	}

	return [valtype::luhn checkdigit $value {CREDITCARD AMEX}]
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

package provide valtype::creditcard::amex 1
