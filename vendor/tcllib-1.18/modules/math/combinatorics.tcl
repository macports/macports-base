#----------------------------------------------------------------------
#
# math/combinatorics.tcl --
#
#	This file contains definitions of mathematical functions
#	useful in combinatorial problems.  
#
# Copyright (c) 2001, by Kevin B. Kenny.  All rights reserved.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: combinatorics.tcl,v 1.5 2004/02/09 19:31:54 hobbs Exp $
#
#----------------------------------------------------------------------

package require Tcl 8.0

namespace eval ::math {

    # Commonly used combinatorial functions

    # ln_Gamma is spelt thus because it's a capital gamma (\u0393)

    namespace export ln_Gamma;		# Logarithm of the Gamma function
    namespace export factorial;		# Factorial
    namespace export choose;		# Binomial coefficient

    # Note that Beta is spelt thus because it's conventionally a
    # capital beta (\u0392).  It is exported from the package even
    # though its name is capitalized.

    namespace export Beta;		# Beta function

}

#----------------------------------------------------------------------
#
# ::math::InitializeFactorial --
#
#	Initialize a table of factorials for small integer arguments.
#
# Parameters:
#	None.
#
# Results:
#	None.
#
# Side effects:
#	The variable, ::math::factorialList, is initialized to hold
#	a table of factorial n for 0 <= n <= 170.
#
# This procedure is called once when the 'factorial' procedure is
# being loaded.
#
#----------------------------------------------------------------------

proc ::math::InitializeFactorial {} {

    variable factorialList

    set factorialList [list 1]
    set f 1
    for { set i 1 } { $i < 171 } { incr i } {
	if { $i > 12. } {
	    set f [expr { $f * double($i)}]
	} else {
	    set f [expr { $f * $i }]
	}
	lappend factorialList $f
    }

}

#----------------------------------------------------------------------
#
# ::math::InitializePascal --
#
#	Precompute the first few rows of Pascal's triangle and store
#	them in the variable ::math::pascal
#
# Parameters:
#	None.
#
# Results:
#	None.
#
# Side effects:
#	::math::pascal is initialized to a flat list containing 
#	the first 34 rows of Pascal's triangle.	 C(n,k) is to be found
#	at [lindex $pascal $i] where i = n * ( n + 1 ) + k.  No attempt
#	is made to exploit symmetry.
#
#----------------------------------------------------------------------

proc ::math::InitializePascal {} {

    variable pascal

    set pascal [list 1]
    for { set n 1 } { $n < 34 } { incr n } {
	lappend pascal 1
	set l2 [list 1]
	for { set k 1 } { $k < $n } { incr k } {
	    set km1 [expr { $k - 1 }]
	    set c [expr { [lindex $l $km1] + [lindex $l $k] }]
	    lappend pascal $c
	    lappend l2 $c
	}
	lappend pascal 1
	lappend l2 1
	set l $l2
    }

}

#----------------------------------------------------------------------
#
# ::math::ln_Gamma --
#
#	Returns ln(Gamma(x)), where x >= 0
#
# Parameters:
#	x - Argument to the Gamma function.
#
# Results:
#	Returns the natural logarithm of Gamma(x).
#
# Side effects:
#	None.
#
# Gamma(x) is defined as:
#
#		  +inf
#		    _
#		   |	x-1  -t
#	Gamma(x)= _|   t    e	dt
#
#		   0
#
# The approximation used here is from Lanczos, SIAM J. Numerical Analysis,
# series B, volume 1, p. 86.  For x > 1, the absolute error of the
# result is claimed to be smaller than 5.5 * 10**-10 -- that is, the
# resulting value of Gamma when exp( ln_Gamma( x ) ) is computed is
# expected to be precise to better than nine significant figures.
#
#----------------------------------------------------------------------

proc ::math::ln_Gamma { x } {

    # Handle the common case of a real argument that's within the
    # permissible range.

    if { [string is double -strict $x]
	 && ( $x > 0 )
	 && ( $x <= 2.5563481638716906e+305 )
     } {
	set x [expr { $x - 1.0 }]
	set tmp [expr { $x + 5.5 }]
	set tmp [ expr { ( $x + 0.5 ) * log( $tmp ) - $tmp }]
	set ser 1.0
	foreach cof {
	    76.18009173 -86.50532033 24.01409822
	    -1.231739516 .00120858003 -5.36382e-6
	} {
	    set x [expr { $x + 1.0 }]
	    set ser [expr { $ser + $cof / $x }]
	}
	return [expr { $tmp + log( 2.50662827465 * $ser ) }]
    } 

    # Handle the error cases.

    if { ![string is double -strict $x] } {
	return -code error [expectDouble $x]
    }

    if { $x <= 0.0 } {
	set proc [lindex [info level 0] 0]
	return -code error \
	    -errorcode [list ARITH DOMAIN \
			"argument to $proc must be positive"] \
	    "argument to $proc must be positive"
    }

    return -code error \
	-errorcode [list ARITH OVERFLOW \
		    "floating-point value too large to represent"] \
	"floating-point value too large to represent"
	
}

#----------------------------------------------------------------------
#
# math::factorial --
#
#	Returns the factorial of the argument x.
#
# Parameters:
#	x -- Number whose factorial is to be computed.
#
# Results:
#	Returns x!, the factorial of x.
#
# Side effects:
#	None.
#
# For integer x, 0 <= x <= 12, an exact integer result is returned.
#
# For integer x, 13 <= x <= 21, an exact floating-point result is returned
# on machines with IEEE floating point.
#
# For integer x, 22 <= x <= 170, the result is exact to 1 ULP.
#
# For real x, x >= 0, the result is approximated by computing
# Gamma(x+1) using the ::math::ln_Gamma function, and the result is
# expected to be precise to better than nine significant figures.
#
# It is an error to present x <= -1 or x > 170, or a value of x that
# is not numeric.
#
#----------------------------------------------------------------------

proc ::math::factorial { x } {

    variable factorialList

    # Common case: factorial of a small integer

    if { [string is integer -strict $x]
	 && $x >= 0
	 && $x < [llength $factorialList] } {
	return [lindex $factorialList $x]
    }

    # Error case: not a number

    if { ![string is double -strict $x] } {
	return -code error [expectDouble $x]
    }

    # Error case: gamma in the left half plane

    if { $x <= -1.0 } {
	set proc [lindex [info level 0] 0]
	set message "argument to $proc must be greater than -1.0"
	return -code error -errorcode [list ARITH DOMAIN $message] $message
    }

    # Error case - gamma fails

    if { [catch { expr {exp( [ln_Gamma [expr { $x + 1 }]] )} } result] } {
	return -code error -errorcode $::errorCode $result
    }

    # Success - computed factorial n as Gamma(n+1)

    return $result

}

#----------------------------------------------------------------------
#
# ::math::choose --
#
#	Returns the binomial coefficient C(n,k) = n!/k!(n-k)!
#
# Parameters:
#	n -- Number of objects in the sampling pool
#	k -- Number of objects to be chosen.
#
# Results:
#	Returns C(n,k).	 
#
# Side effects:
#	None.
#
# Results are expected to be accurate to ten significant figures.
# If both parameters are integers and the result fits in 32 bits, 
# the result is rounded to an integer.
#
# Integer results are exact up to at least n = 34.
# Floating point results are precise to better than nine significant 
# figures.
#
#----------------------------------------------------------------------

proc ::math::choose { n k } {

    variable pascal

    # Use a precomputed table for small integer args

    if { [string is integer -strict $n]
	 && $n >= 0 && $n < 34
	 && [string is integer -strict $k]
	 && $k >= 0 && $k <= $n } {

	set i [expr { ( ( $n * ($n + 1) ) / 2 ) + $k }]

	return [lindex $pascal $i]

    }

    # Test bogus arguments

    if { ![string is double -strict $n] } {
	return -code error [expectDouble $n]
    }
    if { ![string is double -strict $k] } {
	return -code error [expectDouble $k]
    }

    # Forbid negative n

    if { $n < 0. } {
	set proc [lindex [info level 0] 0]
	set msg "first argument to $proc must be non-negative"
	return -code error -errorcode [list ARITH DOMAIN $msg] $msg
    }

    # Handle k out of range

    if { [string is integer -strict $k] && [string is integer -strict $n]
	 && ( $k < 0 || $k > $n ) } {
	return 0
    }

    if { $k < 0. } {
	set proc [lindex [info level 0] 0]
	set msg "second argument to $proc must be non-negative,\
                 or both must be integers"
	return -code error -errorcode [list ARITH DOMAIN $msg] $msg
    }

    # Compute the logarithm of the desired binomial coefficient.

    if { [catch { expr { [ln_Gamma [expr { $n + 1 }]]
			 - [ln_Gamma [expr { $k + 1 }]]
			 - [ln_Gamma [expr { $n - $k + 1 }]] } } r] } {
	return -code error -errorcode $::errorCode $r
    }

    # Compute the binomial coefficient itself

    if { [catch { expr { exp( $r ) } } r] } {
	return -code error -errorcode $::errorCode $r
    }

    # Round to integer if both args are integers and the result fits

    if { $r <= 2147483647.5 
	       && [string is integer -strict $n]
	       && [string is integer -strict $k] } {
	return [expr { round( $r ) }]
    }

    return $r

}

#----------------------------------------------------------------------
#
# ::math::Beta --
#
#	Return the value of the Beta function of parameters z and w.
#
# Parameters:
#	z, w : Two real parameters to the Beta function
#
# Results:
#	Returns the value of the Beta function.
#
# Side effects:
#	None.
#
# Beta( w, z ) is defined as:
#
#				  1_
#				  |  (z-1)     (w-1)
# Beta( w, z ) = Beta( z, w ) =	  | t	  (1-t)	     dt
#				 _|
#				  0
#
#	       = Gamma( z ) Gamma( w ) / Gamma( z + w )
#
# Results are returned as a floating point number precise to better
# than nine significant figures for w, z > 1.
#
#----------------------------------------------------------------------

proc ::math::Beta { z w } {

    # Check form of both args so that domain check can be made

    if { ![string is double -strict $z] } {
	return -code error [expectDouble $z]
    }
    if { ![string is double -strict $w] } {
	return -code error [expectDouble $w]
    }

    # Check sign of both args

    if { $z <= 0.0 } {
	set proc [lindex [info level 0] 0]
	set msg "first argument to $proc must be positive"
	return -code error -errorcode [list ARITH DOMAIN $msg] $msg
    }
    if { $w <= 0.0 } {
	set proc [lindex [info level 0] 0]
	set msg "second argument to $proc must be positive"
	return -code error -errorcode [list ARITH DOMAIN $msg] $msg
    }

    # Compute beta using gamma function, keeping stack trace clean.

    if { [catch { expr { exp( [ln_Gamma $z] + [ln_Gamma $w]
			      - [ln_Gamma [ expr { $z + $w }]] ) } } beta] } {

	return -code error -errorcode $::errorCode $beta

    } 

    return $beta

}

#----------------------------------------------------------------------
#
# Initialization of this file:
#
#	Initialize the precomputed tables of factorials and binomial
#	coefficients.
#
#----------------------------------------------------------------------

namespace eval ::math {
    InitializeFactorial
    InitializePascal
}
