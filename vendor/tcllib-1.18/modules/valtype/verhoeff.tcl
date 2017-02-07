# # ## ### ##### ######## ############# ######################
## Verhoeff test of numbers
#
# The Verhoeff test is similar to the Luhn test to compute and verify
# check digits of identifier numbers, albeit quite a bit stronger,
# i.e. detecting more possible keying errors.
#
# References
#	

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

namespace eval ::valtype::verhoeff {
    namespace import ::valtype::common::*
}

snit::type ::valtype::verhoeff {
    #-------------------------------------------------------------------
    # Type Methods

    typemethod validate {value {code VERHOEFF}} {
	if {[regexp {[^0-9]} $value]} {
	    badchar $code "$code number, expected only digits"
	}

	# Verhoeff test.

	set sum [Sum $value 0]
	if {$sum != 0} {
	    badcheck $code "$code number"
	}
	return $value
    }

    typemethod checkdigit {value {code VERHOEFF}} {
	if {[regexp {[^0-9]} $value]} {
	    badchar $code "$code number, expected only digits"
	}

	# Compute the verhoeff checkdigit. First sum the digits as
	# usual. Note that we start with position 1, as the check
	# digit will go into position 0.

	#return [INVERS [Sum $value 1]]
	return [lindex $ourinv [Sum $value 1]]
    }

    proc Sum {value step} {
	# 8.5 required for lreverse.
	#
	# Compute the verhoeff checkdigit. First sum the digits as
	# usual. Note that we start with position 1 for checkdigit
	# calculation, as the check digit will go into position 0.

	set sum 0
	foreach ch [lreverse [split $value {}]] {
	    #set sum [OP $sum [F step $ch]]
	    # inlined below:
	    set sum [lindex $ourop $sum [lindex $ourf $step $ch]]
	    incr step ; if {$step == 8} { set step 0}
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

    #-------------------------------------------------------------------
    # Operations in D5, and the helper permutations F^k, k in {0,...,7}.

    #proc OP     {a b} { return [lindex $ourop $a $b] }
    #proc INVERS {a}   { return [lindex $ourinv $a] }
    #proc F      {k x} { return [lindex $ourf $k $x] }

    typevariable ourop {
	{0 1 2 3 4 5 6 7 8 9}
	{1 2 3 4 0 6 7 8 9 5}
	{2 3 4 0 1 7 8 9 5 6}
	{3 4 0 1 2 8 9 5 6 7}
	{4 0 1 2 3 9 5 6 7 8}
	{5 9 8 7 6 0 4 3 2 1}
	{6 5 9 8 7 1 0 4 3 2}
	{7 6 5 9 8 2 1 0 4 3}
	{8 7 6 5 9 3 2 1 0 4}
	{9 8 7 6 5 4 3 2 1 0} 
    }

    typevariable ourinv {0 4 3 2 1 5 6 7 8 9}

    typevariable ourf {
	{0 1 2 3 4 5 6 7 8 9}
	{1 5 7 6 2 8 3 0 9 4}
	{5 8 0 3 7 9 6 1 4 2}
	{8 9 1 6 0 4 3 5 2 7}
	{9 4 5 3 1 2 6 8 7 0}
	{4 2 8 6 5 7 3 9 0 1}
	{2 7 9 3 8 0 6 4 1 5}
	{7 0 4 6 9 1 3 2 5 8}
    }
}

# # ## ### ##### ######## ############# ######################
## Ready

package provide valtype::verhoeff 1
