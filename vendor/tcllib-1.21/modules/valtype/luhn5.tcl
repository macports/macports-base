# # ## ### ##### ######## ############# ######################
## Luhn test of numbers - 10+5 variant
## From Rosetta Code
##	http://rosettacode.org/wiki/Luhn_test#Tcl
## Author Donal K. Fellows
## See also
##	http://en.wikipedia.org/wiki/Luhn_algorithm
## ISO/IEC 7812-1
##	http://www.iso.org/iso/iso_catalogue/catalogue_tc/catalogue_detail.htm?csnumber=39698
## US Patent 2,950,048 (Aug 23, 1960): expired.
##	http://www.google.com/patents?q=2950048
## Public Domain.
#
# The 10+5 variant of the Luhn test is used by some credit card
# companies to distinguish valid credit card numbers from what could
# be a random selection of digits.
#
# Those companies using credit card numbers that can be validated by
# the Luhn test have numbers that pass the following test:
##
#   1. Reverse the order of the digits in the number.
#
#   2. Take the first, third, ... and every other odd digit in the
#      reversed digits and sum them to form the partial sum s1
#
#   3. Taking the second, fourth ... and every other even digit in the
#      reversed digits:
#
#      a. Multiply each digit by two and sum the digits if the answer
#         is greater than nine to form partial sums for the even digits
#      b. Sum the partial sums of the even digits to form s2
#
#      Note that the steps above induce a simple permutation on digits
#      0-9 which can be handled through a lookup table instead of doing
#      the doubling and summing explicitly.
#
#   4. If s1 + s2 ends in zero or five then the original number is in
#      the form of a valid credit card number as verified by the Luhn test.

# 3.a/3.b lookup table
#   i|0  1  2  3  4  5  6  7  8  9
#  *2|0  2  4  6  8 10 12 14 16 18
# sum|0  2  4  6  8  1  3  5  7  9 (butterfly)

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

namespace eval ::valtype::luhn5 {
    namespace import ::valtype::common::*
}

snit::type ::valtype::luhn5 {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value {code LUHN5}} {
	if {[regexp {[^0-9]} $value]} {
	    badchar $code "$code number, expected only digits"
	}

	# Luhn test.

	set sum [Sum $value 1]
	if {($sum % 10) ni {0 5}} {
	    badcheck $code "$code number"
	}
	return $value
    }

    typemethod checkdigit0 {value {code LUHN5}} {
	if {[regexp {[^0-9]} $value]} {
	    badchar LUHN "$code number, expected only digits"
	}

	# Compute the luhn5 checkdigit 0 % 10.

	set c [expr {10 - ([Sum $value 0] % 10)}]
	if {$c == 10} { set c 0 }
	return $c
    }

    typemethod checkdigit5 {value {code LUHN5}} {
	if {[regexp {[^0-9]} $value]} {
	    badchar LUHN "$code number, expected only digits"
	}

	# Compute the luhn5 checkdigit 5 % 10 (the alternate).
	set c [expr {10 - (([Sum $value 0] + 5) % 10)}]
	if {$c == 10} { set c 0 }
	return $c
    }

    proc Sum {value flip} {
	# Check digit computation starts with flip == 0!
	#
	# In the validation (see above) the check-digit is the last
	# digit, and flip initialized to 1. The next-to-last digit is
	# our last here and processed with the bit flipped. Hence our
	# different, pre-flipped, starting point.

	set sum 0
	foreach ch [lreverse [split $value {}]] {
	    incr sum [lindex {
		{0 1 2 3 4 5 6 7 8 9}
		{0 2 4 6 8 1 3 5 7 9}
	    } [expr {[incr flip] & 1}] $ch]
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

package provide valtype::luhn5 1
