# # ## ### ##### ######## ############# ######################
## Validation of EAN13 numbers.
## EAN = European Article Number
## now   International Article Number, without changing the acronym.
#
# References
#	http://www.cut-the-knot.org/Curriculum/Arithmetic/EAN13.shtml
#	http://www.barcodeisland.com/ean13.phtml
#	http://en.wikipedia.org/wiki/EAN-13

# # ## ### ##### ######## ############# ######################

# The code below implements the interface of a snit validation type,
# making it directly usable with snit's -type option in option
# specifications.

# # ## ### ##### ######## ############# ######################
## Requisites

package require Tcl 8.5
package require snit
package require valtype::common

# # ## ### ##### ######## ############# ######################
## Implementation

namespace eval ::valtype::gs1::ean13 {
    namespace import ::valtype::common::*
}

snit::type ::valtype::gs1::ean13 {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {![regexp {^[0-9]+[Xx]?$} $value]} {
	    badchar EAN13 "EAN13 number, expected only digits, and possibly 'X' or 'x' as checkdigit"
	} elseif {[string length $value] != 13} {
	    badlength EAN13 13 "EAN13 number"
	}

	# FUTURE: Check that the first 3 digits are a valid GS1
	# FUTURE: country code (numeric). See also the ISO 3166-1
	# FUTURE: country codes. Same purpose, different codings (alpha2
	# FUTURE: alpha3, numeric3).

	set sum [Sum $value]
	if {($sum % 10) != 0} {
	    badcheck EAN13 "EAN13 number"
	}

	return $value
    }

    typemethod checkdigit {value} {
	if {![regexp {^[0-9]+[Xx]?$} $value]} {
	    badchar EAN13 "EAN13 number (without checkdigit), expected only digits"
	} elseif {[string length $value] != 12} {
	    badlength EAN13 12 "EAN13 number (without checkdigit)"
	}

	set c [expr {10 - ([Sum $value] % 10)}]
	if {$c == 10} { set c 0 }

	return $c
    }

    proc Sum {value} {
	#  i| 0 1 2 3  4  5  6  7  8  9
	# *3| 0 3 6 9 12 15 18 21 24 27

	set sum 0
	set flip 1
	foreach d [string map {x 10 X 10} [split $value {}]] {
	    incr sum [lindex {
		{0 1 2 3 4 5 6 7 8 9 10}
		{0 3 6 9 12 15 18 21 24 27 30}
	    } [expr {[incr flip] & 1}] $d]
	}
	return $sum
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

package provide valtype::gs1::ean13 1
