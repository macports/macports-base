# # ## ### ##### ######## ############# ######################
## Verify MASTERCARD MASTERCARD credit card number
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

namespace eval ::valtype::creditcard::mastercard {
    namespace import ::valtype::common::*
}

snit::type ::valtype::creditcard::mastercard {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {[string length $value] != 16} {
	    badlength {CREDITCARD MASTERCARD} 16 "CREDITCARD MASTERCARD number"
	} elseif {[string index $value 0] ne "5"} {
	    badprefix {CREDITCARD MASTERCARD} 5 "CREDITCARD MASTERCARD number"
	}

	return [valtype::luhn validate $value {CREDITCARD MASTERCARD}]
    }

    typemethod checkdigit {value} {
	if {[string length $value] != 15} {
	    badlength {CREDITCARD MASTERCARD} 15 "CREDITCARD MASTERCARD number without checkdigit"
	} elseif {[string index $value 0] ne "5"} {
	    badprefix {CREDITCARD MASTERCARD} 5 "CREDITCARD MASTERCARD number without checkdigit"
	}

	return [valtype::luhn checkdigit $value {CREDITCARD MASTERCARD}]
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

package provide valtype::creditcard::mastercard 1
