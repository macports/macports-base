# # ## ### ##### ######## ############# ######################
## Verify DISCOVER credit card number
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

namespace eval ::valtype::creditcard::discover {
    namespace import ::valtype::common::*
}

# # ## ### ##### ######## ############# ######################
## Implementation

snit::type ::valtype::creditcard::discover {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {[string length $value] != 16} {
	    badlength {CREDITCARD DISCOVER} 16 "CREDITCARD DISCOVER number"
	} elseif {![string match 6011* $value] &&
		  ![string match 65* $value]} {
	    badprefix {CREDITCARD DISCOVER} {6011 65} "CREDITCARD DISCOVER number"
	}

	return [valtype::luhn validate $value {CREDITCARD DISCOVER}]
    }

    typemethod checkdigit {value} {
	if {[string length $value] != 15} {
	    badlength {CREDITCARD DISCOVER} 15 "CREDITCARD DISCOVER number without checkdigit"
	} elseif {![string match 6011* $value] &&
		  ![string match 65* $value]} {
	    badprefix {CREDITCARD DISCOVER} {6011 65} "CREDITCARD DISCOVER number without checkdigit"
	}

	return [valtype::luhn checkdigit $value {CREDITCARD DISCOVER}]
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

package provide valtype::creditcard::discover 1
