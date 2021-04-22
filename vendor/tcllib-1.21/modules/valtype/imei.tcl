# # ## ### ##### ######## ############# ######################
## IMEI (International Mobile Equipment Identity)
## References
##	http://en.wikipedia.org/wiki/IMEI
##	http://www.3gpp.org/ftp/Specs/html-info/23003.htm
## Short notes
##	14-digit number + check digit.
##	Embeds information on origin, model, and serial number of the device.
##	Passes Luhn test as is.

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

namespace eval ::valtype::imei {
    namespace import ::valtype::common::*
}

snit::type ::valtype::imei {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {[string length $value] != 15} {
	    badlength IMEI 15 "IMEI number"
	}
	return [valtype::luhn validate $value IMEI]
    }

    typemethod checkdigit {value} {
	if {[string length $value] != 14} {
	    badlength IMEI 14 "IMEI number (without checkdigit)"
	}
	return [valtype::luhn checkdigit $value IMEI]
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

package provide valtype::imei 1
