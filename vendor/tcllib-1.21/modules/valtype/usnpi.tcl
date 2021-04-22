# # ## ### ##### ######## ############# ######################
## US NPI (National Provider Identifier) for Medicare services.
## Reference
##	http://en.wikipedia.org/wiki/National_Provider_Identifier
## Short notes
##	10-digit number. No embedded information.
##	Passes Luhn test when prefixed with '80480'.

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

namespace eval ::valtype::usnpi {
    namespace import ::valtype::common::*
}

snit::type ::valtype::usnpi {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {[string length $value] != 10} {
	    badlength US-NPI 10 "US-NPI number"
	}
	valtype::luhn validate 80480$value US-NPI
	return $value
    }

    typemethod checkdigit {value} {
	if {[string length $value] != 9} {
	    badlength US-NPI 9 "US-NPI number (without checkdigit)"
	}
	return [valtype::luhn checkdigit 80480$value US-NPI]
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

package provide valtype::usnpi 1
