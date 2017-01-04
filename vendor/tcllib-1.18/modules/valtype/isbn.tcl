# # ## ### ##### ######## ############# ######################
## Validation of ISBN numbers.
#
## ISBN-10 and -13 numbers are handled. The later are issued since
## Jan 1, 2007. ISBN-10 numbers indicate books issued before that date.
## I.e. Books after the date do not have ISBN-10 numbers any longer.
## Books with an ISBN-10 have a canconical ISBN-13 equivalent
## number. See method '13of'.

## Note that ISBN-13 numbers are essentially EAN-13 numbers with
## country codes 'Bookland' and 'Musicland', i.e. 978 and 979.
#
# References
#	http://www.augustana.ab.ca/~mohrj/algorithms/checkdigit.html
#	http://en.wikipedia.org/wiki/International_Standard_Book_Number

# # ## ### ##### ######## ############# ######################

# The code below implements the interface of a snit validation type,
# making it directly usable with snit's -type option in option
# specifications.

# The result of the validation is always a proper isbn13 code, even if
# the input was isbn10. In this manner inputs are normalized to the
# canonical format.

# # ## ### ##### ######## ############# ######################
## Requisites

package require Tcl 8.5
package require snit
package require valtype::common

# # ## ### ##### ######## ############# ######################
## Implementation

namespace eval ::valtype::isbn {
    namespace import ::valtype::common::*
}

snit::type ::valtype::isbn {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value} {
	if {![regexp {^[0-9]+[Xx]?$} $value]} {
	    badchar ISBN "ISBN number, expected only digits, and possibly 'X' or 'x' as checkdigit"
	}

	switch -exact -- [string length $value] {
	    10 {
		set sum 0
		foreach \
		    d [string map {x 10 X 10} [lreverse [split $value {}]]] \
		    w {1 2 3 4 5 6 7 8 9 10} {
			incr sum [expr {$d * $w}]
		    }
		if {($sum % 11) != 0} {
		    badcheck ISBN "ISBN number"
		}

		# Normalize isbn10 to its isbn13 equivalent.

		set n 978[string range $value 0 end-1]
		return $n[$type checkdigit $n]
	    }
	    13 {
		if {![string match 978* $value] &&
		    ![string match 979* $value]} {
		    badprefix ISBN {978 979} "ISBN number"
		}

		set sum [Sum $value]
		if {($sum % 10) != 0} {
		    badcheck ISBN "ISBN number"
		}
	    }
	    default {
		badlength ISBN {10 13} "ISBN number"
	    }
	}

	return $value
    }

    typemethod checkdigit {value} {
	if {![regexp {^[0-9]+[Xx]?$} $value]} {
	    badchar ISBN "ISBN number (without checkdigit), expected only digits"
	}

	switch -exact -- [string length $value] {
	    9 {
		set sum 0
		foreach \
		    d [lreverse [split $value {}]] \
		    w {2 3 4 5 6 7 8 9 10} {
			incr sum [expr {$d * $w}]
		    }

		set c [expr {11 - ($sum % 11)}]
		if {$c == 11} { set c 0 }
		if {$c == 10} { set c X }
	    }
	    12 {
		if {![string match 978* $value] &&
		    ![string match 979* $value]} {
		    badprefix ISBN {978 979} "ISBN number (without checkdigit)"
		}

		set c [expr {10 - ([Sum $value] % 10)}]
		if {$c == 10} { set c 0 }
	    }
	    default {
		badlength ISBN {9 12} "ISBN number (without checkdigit)"
	    }
	}

	return $c
    }

    # Convert isbn10 to isbn13.

    # Note that isbn13 numbers are valid ean13 codes with 'country
    # code' 978, aka 'bookland'. As space has run out the country code
    # 979 'Musicland' (see ISMN) is repurposed and phased in. This
    # however does not affect the conversion of isbn10 numbers, their
    # equivalents are all in the 978 region.

    typemethod 13of {value} {
	if {![regexp {^[0-9]+[Xx]?$} $value]} {
	    badchar ISBN "ISBN-10 number, expected only digits, and possibly 'X' or 'x' as checkdigit"
	} elseif {[string length $value] != 10} {
	    badlength ISBN 10 "ISBN-10 number"
	}

	# Strip the -10 check digit, prefix the remainder with the
	# bookland country code and recalculate the check digit, via
	# -13.

	set n 978[string range $value 0 end-1]
	return $n[$type checkdigit $n]
    }

    # NOTE: Same as EAN13
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

package provide valtype::isbn 1
