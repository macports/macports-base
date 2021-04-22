# exact.tcl --
#
#	Tcl package for exact real arithmetic.
#
# Copyright (c) 2015 by Kevin B. Kenny
#
# See the file "license.terms" for information on usage and redistribution of
# this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# This package provides a library for performing exact
# computations over the computable real numbers. The algorithms
# are largely based on the ones described in:
#
# Potts, Peter John. _Exact Real Arithmetic using Möbius Transformations._
# PhD thesis, University of London, July 1998.
# http://www.doc.ic.ac.uk/~ae/papers/potts-phd.pdf
#
# Some of the algorithms for the elementary functions are found instead
# in:
#
# Menissier-Morain, Valérie. _Arbitrary Precision Real Arithmetic:
# Design and Algorithms. J. Symbolic Computation 11 (1996)
# http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.31.8983
#
#-----------------------------------------------------------------------------

package require Tcl 8.6
package require grammar::aycock 1.0

namespace eval math::exact {

    namespace eval function {
	namespace path ::math::exact
    }
    namespace path ::tcl::mathop

    # math::exact::parser --
    #
    #	Grammar for parsing expressions in the exact real calculator
    #
    # The expression syntax is almost exactly that of Tcl expressions,
    # minus Tcl arrays, square-bracket substitution, and noncomputable
    # operations such as equality, comparisons, bit and Boolean operations,
    # and ?:.

    variable parser [grammar::aycock::parser {

	target ::= expression {
	    lindex $_ 0
	}

	expression ::= expression addop term {
	    {*}$_
	}
	expression ::= term {
	    lindex $_ 0
	}
	addop ::= + {
	    lindex $_ 0
	}
	addop ::= - {
	    lindex $_ 0
	}

	term ::= term mulop factor {
	    {*}$_
	}
	term ::= factor {
	    lindex $_ 0
	}
	mulop ::= * {
	    lindex $_ 0
	}
	mulop ::= / {
	    lindex $_ 0
	}

	factor ::= addop factor {
	    switch -exact -- [lindex $_ 0] {
		+ {
		    set result [lindex $_ 1]
		}
		- {
		    set result [[lindex $_ 1] U-]
		}
	    }
	    set result
	}
	factor ::= primary ** factor {
	    {*}$_
	}
	factor ::= primary {
	    lindex $_ 0
	}

	primary ::= {$} bareword {
	    uplevel [dict get $clientData caller] set [lindex $_ 1]
	}
	primary ::= number {
	    [dict get $clientData namespace]::V new [list [lindex $_ 0] 1]
	}
	primary ::= bareword ( ) {
	    [dict get $clientData namespace]::function::[lindex $_ 0]
	}
	primary ::= bareword ( arglist ) {
	    [dict get $clientData namespace]::function::[lindex $_ 0] \
		{*}[lindex $_ 2]
	}
	primary ::= ( expression ) {
	    lindex $_ 1
	}
	arglist ::= expression {
	    set _
	}
	arglist ::= arglist , expression {
	    linsert [lindex $_ 0] end [lindex $_ 2]
	}

    }]
}

# math::exact::Lexer --
#
#	Lexer for the arithmetic expressions that the 'math::exact' package
#	can evaluate.
#
# Results:
#	Returns a two element list. The first element is a list of the
#	lexical values of the tokens that were found in the expression;
#	the second is a list of the semantic values of the tokens. The
#	two sublists are the same length.

proc ::math::exact::Lexer {expression} {
    set start 0
    set tokens {}
    set values {}
    while {$expression ne {}} {
	if {[regexp {^\*\*(.*)} $expression -> rest]} {

	    # Exponentiation

	    lappend tokens **
	    lappend values **
	} elseif {[regexp {^([-+/*$(),])(.*)} $expression -> token rest]} {

	    # Single-character operators

	    lappend tokens $token
	    lappend values $token
	} elseif {[regexp {^([[:alpha:]][[:alnum:]_]*)(.*)} \
		       $expression -> token rest]} {

	    # Variable and function names

	    lappend tokens bareword
	    lappend values $token
	} elseif {[regexp -nocase {^([[:digit:]]+)(.*)} $expression -> \
		       token rest] } {

	    # Numbers

	    lappend tokens number
	    lappend values $token

	} elseif {[regexp {^[[:space:]]+(.*)} $expression -> rest]} {

	    # Whitespace

	} else {

	    # Anything else is an error

	    return -code error \
		-errorcode [list MATH EXACT EXPR INVCHAR \
				[string index $expression 0]] \
		[list invalid character [string index $expression 0]] \
	}
	set expression $rest
    }
    return [list $tokens $values]
}

# math::exact::K --
#
#	K combinator. Returns its first argumetn
#
# Parameters:
#	a - Return value
#	b - Value to discard
#
# Results:
#	Returns the first argument

proc ::math::exact::K {a b} {return $a}

# math::exact::exactexpr --
#
#	Evaluates an exact real expression.
#
# Parameters:
#	expr - Expression to evaluate. Variables in the expression are
#	       assumed to be reals, which are represented as Tcl objects.
#
# Results:
#	Returns a Tcl object representing the expression's value.
#
# The returned object must have its refcount incremented with [ref] if
# the caller retains a reference, and in general it is expected that a
# user of a real will [ref] the object when storing it in a variable and
# [unref] it again when the variable goes out of scope or is overwritten.

proc ::math::exact::exactexpr {expr} {
    variable parser
    set result [$parser parse {*}[Lexer $expr] \
		    [dict create \
			 caller "#[expr {[info level] - 1}]" \
			 namespace [namespace current]]]
}

# Basic data types

# A vector is a list {a b}. It can represent the rational number {a/b}

# A matrix is a list of its columns {{a b} {c d}}. In addition to
# the ordinary rules of linear algebra, it represents the linear
# transform (ax+b)/(cx+d).

# If x is presumed to lie in the interval [0, Inf) then this transform
# applied to x will lie in the interval [b/d, a/c), so the matrix
# {{a b} {c d}} can represent that interval. The interval [0,Inf)
# can be represented by the identity matrix {{1 0} {0 1}}

# Moreover, if x  = {p/q} is a rational number, then
#    (ax+b)/(cx+d) = (a(p/q)+b)/(c(p/q)+d)
#                  = ((ap+bq)/q)/(cp+dq)/q)
#                  = (ap+bq)/(cp+dq)
# which is the rational number represented by {{a c} {b d}} {p q}
# using the conventional rule of vector-matrix multiplication.

# Note that matrices used for this purpose are unique only up to scaling.
# If (ax+b)/(cx+d) is a rational number, then (eax+eb)/(ecx+ed) represents
# the same rational number. This means that matrix inversion may be replaced
# by matrix reversion: for {{a b} {c d}}, simply form the list of cofactors
# {{d -b} {-c a}}, without dividing by the determinant. The reverse of a matrix
# is well defined even if the matrix is singular.

# A tensor of the third degree is a list of its levels:
#  {{{a b} {c d}} {{e f} {g h}}}

# math::exact::gcd --
#
#	Greatest common divisor of a set of integers
#
# Parameters:
#	The integers whose gcd is to be found
#
# Results:
#	Returns the gcd

proc ::math::exact::gcd {a args} {
    foreach b $args {
	if {$a > $b} {
	    set t $b; set b $a; set a $t
	}
	while {$b > 0} {
	    set t $b
	    set b [expr {$a % $b}]
	    set a $t
	}
    }
    return $a
}

# math::exact::trans --
#
#	Transposes a 2x2 matrix or a 2x2x2 tensor
#
# Parameters:
#	x - Object to transpose
#
# Results:
#	Returns the transpose

proc ::math::exact::trans {x} {
    lassign $x ab cd
    lassign $ab a b
    lassign $cd c d
    tailcall list [list $a $c] [list $b $d]
}

# math::exact::determinant --
#
#	Calculates the determinant of a 2x2 matrix
#
# Parameters:
#	x - Matrix
#
# Results:
#	Returns the determinant.

proc ::math::exact::determinant {x} {
    lassign $x ab cd
    lassign $ab a b
    lassign $cd c d
    return [expr {$a*$d - $b*$c}]
}

# math::exact::reverse --
#
#	Calculates the reverse of a 2x2 matrix, which is its inverse times
#	its determinant.
#
# Parameters:
#	x - Matrix
#
# Results:
#	Returns reverse[x].
#
# Notes:
#	The reverse is well defined even for singular matrices.

proc ::math::exact::reverse {x} {
    lassign $x ab cd
    lassign $ab a b
    lassign $cd c d
    tailcall list [list $d [expr {-$b}]] [list [expr {-$c}] $a]
}

# math::exact::veven --
#
#	Tests if both components of a 2-vector are even.
#
# Parameters:
#	x - Vector to test
#
# Results:
#	Returns 1 if both components are even, 0 otherwise.

proc ::math::exact::veven {x} {
    lassign $x a b
    return [expr {($a % 2 == 0) && ($b % 2 == 0)}]
}

# math::exact::meven --
#
#	Tests if all components of a 2x2 matrix are even.
#
# Parameters:
#	x - Matrix to test
#
# Results:
#	Returns 1 if all components are even, 0 otherwise.

proc ::math::exact::meven {x} {
    lassign $x a b
    return [expr {[veven $a] && [veven $b]}]
}

# math::exact::teven --
#
#	Tests if all components of a 2x2x2 tensor are even
#
# Parameters:
#	x - Tensor to test
#
# Results:
#	Returns 1 if all components are even, 0 otherwise

proc ::math::exact::teven {x} {
    lassign $x a b
    return [expr {[meven $a] && [meven $b]}]
}

# math::exact::vhalf --
#
#	Divides both components of a 2-vector by 2
#
# Parameters:
#	x - Vector to scale
#
# Results:
#	Returns the scaled vector

proc ::math::exact::vhalf {x} {
    lassign $x a b
    tailcall list [expr {$a / 2}] [expr {$b / 2}]
}

# math::exact::mhalf --
#
#	Divides all components of a 2x2 matrix by 2
#
# Parameters:
#	x - Matrix to scale
#
# Results:
#	Returns the scaled matrix

proc ::math::exact::mhalf {x} {
    lassign $x a b
    tailcall list [vhalf $a] [vhalf $b]
}

# math::exact::thalf --
#
#	Divides all components of a 2x2x2 tensor by 2
#
# Parameters:
#	x - Tensor to scale
#
# Results:
#	Returns the scaled tensor

proc ::math::exact::thalf {x} {
    lassign $x a b
    tailcall list [mhalf $a] [mhalf $b]
}

# math::exact::vscale --
#
#	Removes all common factors of 2 from the two components of a 2-vector
#
# Paramters:
#	x - Vector to scale
#
# Results:
#	Returns the scaled vector

proc ::math::exact::vscale {x} {
    while {[veven $x]} {
	set x [vhalf $x]
    }
    return $x
}

# math::exact::mscale --
#
#	Removes all common factors of 2 from the two components of a
#	2x2 matrix
#
# Paramters:
#	x - Matrix to scale
#
# Results:
#	Returns the scaled matrix

proc ::math::exact::mscale {x} {
    while {[meven $x]} {
	set x [mhalf $x]
    }
    return $x
}

# math::exact::tscale --
#
#	Removes all common factors of 2 from the two components of a
#	2x2x2 tensor
#
# Paramters:
#	x - Tensor to scale
#
# Results:
#	Returns the scaled tensor

proc ::math::exact::tscale {x} {
    while {[teven $x]} {
	set x [thalf $x]
    }
    return $x
}

# math::exact::vreduce --
#
#	Reduces a vector (i.e., a rational number) to lowest terms
#
# Parameters:
#	x - Vector to scale
#
# Results:
#	Returns the scaled vector

proc ::math::exact::vreduce {x} {
    lassign $x a b
    set g [gcd $a $b]
    tailcall list [expr {$a / $g}] [expr {$b / $g}]
}

# math::exact::mreduce --
#
#	Removes all common factors from the two components of a
#	2x2 matrix
#
# Paramters:
#	x - Matrix to scale
#
# Results:
#	Returns the scaled matrix
#
# This procedure suffices to reduce the matrix to lowest terms if the matrix
# was constructed by pre- or post-multiplying a series of sign and digit
# matrices.

proc ::math::exact::mreduce {x} {
    lassign $x ab cd
    lassign $ab a b
    lassign $cd c d
    set g [gcd $a $b $c $d]
    tailcall list \
	[list [expr {$a / $g}] [expr {$b / $g}]] \
	[list [expr {$c / $g}] [expr {$d / $g}]]
}

# math::exact::treduce --
#
#	Removes all common factors from the components of a
#	2x2x2 tensor
#
# Paramters:
#	x - Tensor to scale
#
# Results:
#	Returns the scaled tensor
#
# This procedure suffices to reduce a tensor to lowest terms if it was
# constructed by absorbing a digit matrix into a tensor that was already
# in lowest terms.

proc ::math::exact::treduce {x} {
    lassign $x abcd efgh
    lassign $abcd ab cd
    lassign $ab a b
    lassign $cd c d
    lassign $efgh ef gh
    lassign $ef e f
    lassign $gh g h
    set G [gcd $a $b $c $d $e $f $g $h]
    tailcall list \
	[list \
	     [list [expr {$a / $G}] [expr {$b / $G}]] \
	     [list [expr {$c / $G}] [expr {$d / $G}]]] \
	[list \
	     [list [expr {$e / $G}] [expr {$f / $G}]] \
	     [list [expr {$g / $G}] [expr {$h / $G}]]]
}

# math::exact::vadd --
#
#	Adds two 2-vectors
#
# Parameters:
#	x - First vector
#	y - Second vector
#
# Results:
#	Returns the vector sum

proc ::math::exact::vadd {x y} {
    lmap p $x q $y {expr {$p + $q}}
}

# math::exact::madd --
#
#	Adds two 2x2 matrices
#
# Parameters:
#	A - First matrix
#	B - Second matrix
#
# Results:
#	Returns the matrix sum

proc ::math::exact::madd {A B} {
    lmap x $A y $B {
	lmap p $x q $y {expr {$p + $q}}
    }
}

# math::exact::tadd --
#
#	Adds two 2x2x2 tensors
#
# Parameters:
#	U - First tensor
#	V - Second tensor
#
# Results:
#	Returns the tensor sum

proc ::math::exact::tadd {U V} {
    lmap A $U B $V {
	lmap x $A y $B {
	    lmap p $x q $y {expr {$p + $q}}
	}
    }
}

# math::exact::mdotv --
#
#	2x2 matrix times 2-vector
#
# Parameters;
#	A - Matrix
#	x - Vector
#
# Results:
#	Returns the product vector

proc ::math::exact::mdotv {A x} {
    lassign $A ab cd
    lassign $ab a b
    lassign $cd c d
    lassign $x e f
    tailcall list [expr {$a*$e + $c*$f}] [expr {$b*$e + $d*$f}]
}

# math::exact::mdotm --
#
#	Product of two matrices
#
# Parameters:
#	A - Left matrix
#	B - Right matrix
#
# Results:
#	Returns the matrix product

proc ::math::exact::mdotm {A B} {
    lassign $B x y
    tailcall list [mdotv $A $x] [mdotv $A $y]
}

# math::exact::mdott --
#
#	Product of a matrix and a tensor
#
# Parameters:
#	A - Matrix
#	T - Tensor
#
# Results:
#	Returns the product tensor

proc ::math::exact::mdott {A T} {
    lassign $T B C
    tailcall list [mdotm $A $B] [mdotm $A $C]
}

# math::exact::trightv --
#
#	Right product of a tensor and a vector
#
# Parameters:
#	T - Tensor
#	v - Right-hand vector
#
# Results:
#	Returns the product matrix

proc ::math::exact::trightv {T v} {
    lassign $T m n
    tailcall list [mdotv $m $v] [mdotv $n $v]
}

# math::exact::trightm --
#
#	Right product of a tensor and a matrix
#
# Parameters:
#	T - Tensor
#	A - Right-hand matrix
#
# Results:
#	Returns the product tensor

proc ::math::exact::trightm {T A} {
    lassign $T m n
    tailcall list [mdotm $m $A] [mdotm $n $A]
}

# math::exact::tleftv --
#
#	Left product of a tensor and a vector
#
# Parameters:
#	T - Tensor
#	v - Left-hand vector
#
# Results:
#	Returns the product matrix

proc ::math::exact::tleftv {T v} {
    tailcall trightv [trans $T] $v
}

# math::exact::tleftm --
#
#	Left product of a tensor and a matrix
#
# Parameters:
#	T - Tensor
#	A - Left-hand matrix
#
# Results:
#	Returns the product tensor

proc ::math::exact::tleftm {T A} {
    tailcall trans [trightm [trans $T] $A]
}

# math::exact::vsign --
#
#	Computes the 'sign function' of a vector.
#
# Parameters:
#	v - Vector whose sign function is needed
#
# Results:
#	Returns the result of the sign function.
#
# a	b	sign
# -	-	 -1
# -	0	 -1
# -	+	  0
# 0	-	 -1
# 0	0	  0
# 0	+	  1
# +	-	  0
# +	0	  1
# +	+	  1
#
# If the quotient a/b is negative or indeterminate, the result is zero.
# If the quotient a/b is zero, the result is the sign of b.
# If the quotient a/b is positive, the result is the common sign of the
# operands, which are known to be of like sign
# If the quotient a/b is infinite, the result is the sign of a.

proc ::math::exact::sign {v} {
    lassign $v a b
    if {$a < 0} {
	if {$b <= 0} {
	    return -1
	} else {
	    return 0
	}
    } elseif {$a == 0} {
	if {$b < 0} {
	    return -1
	} elseif {$b == 0} {
	    return 0
	} else {
	    return 1
	}
    } else {
	if {$b < 0} {
	    return 0
	} else {
	    return 1
	}
    }
}

# math::exact::vrefines --
#
#	Test if a vector refines.
#
# Parameters:
#	v - Vector to test
#
# Results:
#	1 if the vector refines, 0 otherwise.

proc ::math::exact::vrefines {v} {
    return [expr {[sign $v] != 0}]
}

# math::exact::mrefines --
#
#	Test whether a matrix refines
#
# Parameters:
#	A - Matrix to test
#
# Results:
#	1 if the matrix refines, 0 otherwise.

proc ::math::exact::mrefines {A} {
    lassign $A v w
    set a [sign $v]
    set b [sign $w]
    return [expr {$a == $b && $b != 0}]
}

# math::exact::trefines --
#
#	Tests whether a tensor refines
#
# Parameters:
#	T - Tensor to test.
#
# Results:
#	1 if the tensor refines, 0 otherwise.

proc ::math::exact::trefines {T} {
    lassign $T vw xy
    lassign $vw v w
    lassign $xy x y
    set a [sign $v]
    set b [sign $w]
    set c [sign $x]
    set d [sign $y]
    return [expr {$a == $b && $b == $c && $c == $d && $d != 0}]
}

# math::exact::vlessv -
#
#	Test whether one rational is less than another
#
# Parameters:
#	v, w - Two rational numbers
#
# Returns:
#	The result of the comparison.

proc ::math::exact::vlessv {v w} {
    expr {[determinant [list $v $w]] < 0}
}

# math::exact::mlessv -
#
#	Tests whether a rational interval is less than a vector
#
# Parameters:
#	m - Matrix representing the interval
#	x - Rational to compare against
#
# Results:
#	Returns 1 if m < x, 0 otherwise

proc ::math::exact::mlessv {m x} {
    lassign $m v w
    expr {[vlessv $v $x] && [vlessv $w $x]}
}

# math::exact::mlessm -
#
#	Tests whether one rational interval is strictly less than another
#
# Parameters:
#	m - First interval
#	n - Second interval
#
# Results:
#	Returns 1 if m < n, 0 otherwise

proc ::math::exact::mlessm {m n} {
    lassign $n v w
    expr {[mlessv $m $v] && [mlessv $m $w]}
}

# math::exact::mdisjointm -
#
#	Tests whether two rational intervals are disjoint
#
# Parameters:
#	m - First interval
#	n - Second interval
#
# Results:
#	Returns 1 if the intervals are disjoint, 0 otherwise

proc ::math::exact::mdisjointm {m n} {
    expr {[mlessm $m $n] || [mlessm $n $m]}
}

# math::exact::mAsFloat
#
#	Formats a matrix that represents a rational interval as a floating
#	point number, stopping as soon as a digit is not determined.
#
# Parameters:
#	m - Matrix to format
#
# Results:
#	Returns the floating point number in scientific notation, with no
#	digits to the left of the decimal point.

proc ::math::exact::mAsFloat {m} {

    # Special case: If a number is exact, the determinant is zero.

    set d [determinant $m]
    lassign [lindex $m 0] p q
    if {$d == 0} {
	if {$q < 0} {
	    set p [expr {-$p}]
	    set q [expr {-$q}]
	}
	if {$p == 0} {
	    if {$q == 0} {
		return NaN
	    } else {
		return 0
	    }
	} elseif {$q == 0} {
	    return Inf
	} elseif {$q == 1} {
	    return $p
	} else {
	    set G [gcd $p $q]
	    return [expr {$p/$G}]/[expr {$q/$G}]
	}
    } else {
	tailcall eFormat [scientificNotation $m]
    }
}

# math::exact::scientificNotation --
#
#	Takes a matrix representing a rational interval, and extracts as
#	many decimal digits as can be determined unambiguously
#
# Parameters:
#	m - Matrix to format
#
# Results:
#	Returns a list comprising the decimal exponent, followed by a series of
#	digits of the significand. The decimal point is to the left of the
#	leftmost digit of the significand.
#
#	Returns the empty string if a number is entirely undetermined.

proc ::math::exact::scientificNotation {m} {
    variable iszer
    set n 0
    while {1} {
	if {[vrefines [mdotv [reverse $m] {1 0}]]} {
	    return {}
	} elseif {[mrefines [mdotm $iszer $m]]} {
	    return [linsert [mantissa $m] 0 $n]
	} else {
	    set m [mdotm {{1 0} {0 10}} $m]
	    incr n
	}
    }
}

# math::exact::mantissa --
#
#	Given a matrix m that represents a rational interval whose
#	endpoints are in [0,1), formats as many digits of the represented
#	number as possible.
#
# Parameters:
#	m - Matrix to format
#
# Results:
#	Returns a list of digits

proc ::math::exact::mantissa {m} {
    set retval {}
    set done 0
    while {!$done} {
	set done 1

	# Brute force: try each digit in turn. This could no doubt be
	# improved on.

	for {set j -9} {$j <= 9} {incr j} {
	    set digitMatrix \
		[list [list [expr {$j+1}] 10] [list [expr {$j-1}] 10]]
	    if {[mrefines [mdotm [reverse $digitMatrix] $m]]} {
		lappend retval $j
		set nextdigit [list {10 0} [list [expr {-$j}] 1]]
		set m [mdotm $nextdigit $m]
		set done 0
		break
	    }
	}
    }
    return $retval
}

# math::exact::eFormat --
#
#	Formats a decimal exponent and significand in E format
#
# Parameters:
#	expAndDigits - List whose first element is the exponent and
#		       whose remaining elements are the digits of the
#		       significand.

proc ::math::exact::eFormat {expAndDigits} {

    # An empty sequence of digits is an indeterminate number

    if {[llength $expAndDigits] < 2} {
	return Undetermined
    }
    set significand [lassign $expAndDigits exponent]

    # Accumulate the digits
    set v 0
    foreach digit $significand {
	set v [expr {10 * $v + $digit}]
    }

    # Adjust the exponent if the significand has too few digits.

    set l [llength $significand]
    while {$l > 0 && abs($v) < 10**($l-1)} {
	incr l -1
	incr exponent -1
    }
    incr exponent -1

    # Put in the sign

    if {$v < 0} {
	set result -
	set v [expr {-$v}]
    } else {
	set result {}
    }

    # Put in the significand with the decimal point after the leading digit.

    if {$v == 0} {
	append result 0
    } else {
	append result [string index $v 0] . [string range $v 1 end]
    }

    # Put in the exponent

    append result e $exponent

    return $result
}

# math::exact::showRat --
#
#	Formats an exact rational for printing in E format.
#
# Parameters:
#	v - Two-element list of numerator and denominator.
#
# Results:
#	Returns the quotient in E format.  Nonzero/zero == Infinity,
#	0/0 == NaN.

proc ::math::exact::showRat {v} {
    lassign $v p q
    if {$p != 0 || $q != 0} {
	return [format %e [expr {double($p)/double($q)}]]
    } else {
	return NaN
    }
}

# math::exact::showInterval --
#
#	Formats a rational interval for printing
#
# Parameters:
#	m - Matrix representing the interval
#
# Results:
#	Returns a string representing the interval in E format.

proc ::math::exact::showInterval {m} {
    lassign $m v w
    return "\[[showRat $w] .. [showRat $v]\]"
}

# math::exact::showTensor --
#
#	Formats a tensor for printing
#
# Parameters:
#	t - Tensor to print
#
# Results:
#	Returns a string containing the left and right matrices of the
#	tensor, each represented as an interval.

proc ::math::exact::showTensor {t} {
    lassign $t m n
    return [list [showInterval $m] [showInterval $n]]
}

# math::exact::counted --
#
#	Reference counted object

oo::class create math::exact::counted {
    variable refcount_

    # Constructor builds an object with a zero refcount.
    constructor {} {
	if 0 {
	    puts {}
	    puts "construct: [self object] refcount now 0"
	    for {set i [info frame]} {$i > 0} {incr i -1} {
		set frame [info frame $i]
		if {[dict get $frame type] eq {source}} {
		    set line [dict get $frame line]
		    puts "\t[file tail [dict get $frame file]]:$line"
		    if {$line < 0} {
			if {[dict exists $frame proc]} {
			    puts "\t\t[dict get $frame proc]"
			}
			puts "\t\t\[[dict get $frame cmd]\]"
		    }
		} else {
		    puts $frame
		}
	    }
	}
	incr refcount_
	set refcount_ 0
    }

    # The 'ref' method adds a reference to this object, and returns this object
    method ref {} {
	if 0 {
	    puts {}
	    puts "ref: [self object] refcount now [expr {$refcount_ + 1}]"
	    if {$refcount_ == 0} {
		puts "\t[my dump]"
	    }
	    for {set i [info frame]} {$i > 0} {incr i -1} {
		set frame [info frame $i]
		if {[dict get $frame type] eq {source}} {
		    set line [dict get $frame line]
		    puts "\t[file tail [dict get $frame file]]:$line"
		    if {$line < 0} {
			if {[dict exists $frame proc]} {
			    puts "\t\t[dict get $frame proc]"
			}
			puts "\t\t\[[dict get $frame cmd]\]"
		    }
		} else {
		    puts $frame
		}
	    }
	}
	incr refcount_
	return [self]
    }

    # The 'unref' method removes a reference from this object, and destroys
    # this object if the refcount becomes nonpositive.
    method unref {} {
	if 0 {
	    puts {}
	    puts "unref: [self object] refcount now [expr {$refcount_ - 1}]"
	    for {set i [info frame]} {$i > 0} {incr i -1} {
		set frame [info frame $i]
		if {[dict get $frame type] eq {source}} {
		    set line [dict get $frame line]
		    puts "\t[file tail [dict get $frame file]]:$line"
		    if {$line < 0} {
			if {[dict exists $frame proc]} {
			    puts "\t\t[dict get $frame proc]"
			}
			puts "\t\t\[[dict get $frame cmd]\]"
		    }
		}
	    }
	}

	# Destroying this object can result in a long chain of object
	# destruction and eventually a stack overflow. Instead of destroying
	# immediately, list the objects to be destroyed in
	# math::exact::deleteStack, and destroy them only from the outermost
	# stack level that's running 'unref'.

	if {[incr refcount_ -1] <= 0} {
	    variable ::math::exact::deleteStack

	    # Is this the outermost level?
	    set queueActive [expr {[info exists deleteStack]}]

	    # Schedule this object's destruction
	    lappend deleteStack [self object]
	    if {!$queueActive} {

		# At outermost level, destroy all scheduled objects.
		# Destroying one may schedule another.
		while {[llength $deleteStack] != 0} {
		    set obj [lindex $deleteStack end]
		    set deleteStack \
			[lreplace $deleteStack[set deleteStack {}] end end]
		    $obj destroy
		}

		# Once everything quiesces, delete the list.
		unset deleteStack
	    }
	}
    }

    # The 'refcount' method returns the reference count of this object for
    # debugging.
    method refcount {} {
	return $refcount_
    }

    destructor {
    }
}

# An expression is a vector, a matrix applied to an expression,
# or a tensor applied to two expressions. The inner expressions
# may be constructed lazily.

oo::class create math::exact::Expression {
    superclass math::exact::counted

    # absorbed_, signAndMagnitude_, and leadingDigitAndRest_
    # memoize the return values of the 'absorb', 'getSignAndMagnitude',
    # and 'getLeadingDigitAndRest' methods.

    variable absorbed_ signAndMagnitude_ leadingDigitAndRest_

    # Constructor initializes refcount
    constructor {} {
	next
    }

    # Destructor releases memoized objects
    destructor {
	if {[info exists signAndMagnitude_]} {
	    [lindex $signAndMagnitude_ 1] unref
	}
	if {[info exists absorbed_]} {
	    $absorbed_ unref
	}
	if {[info exists leadingDigitAndRest_]} {
	    [lindex $leadingDigitAndRest_ 1] unref
	}
	next
    }

    # getSignAndMagnitude returns a two-element list:
    # the sign matrix, which is one of ispos, isneg, isinf, and iszer,
    # the magnitude, which is another exact real.
    method getSignAndMagnitude {} {
	if {![info exists signAndMagnitude_]} {
	    if {[my refinesM $::math::exact::ispos]} {
		set signAndMagnitude_ \
		    [list $::math::exact::spos \
			 [[my applyM $::math::exact::ispos] ref]]
	    } elseif {[my refinesM $::math::exact::isneg]} {
		set signAndMagnitude_ \
		    [list $::math::exact::sneg \
			 [[my applyM $::math::exact::isneg] ref]]
	    } elseif {[my refinesM $::math::exact::isinf]} {
		set signAndMagnitude_ \
		    [list $::math::exact::sinf \
			 [[my applyM $::math::exact::isinf] ref]]
	    } elseif {[my refinesM $::math::exact::iszer]} {
		set signAndMagnitude_ \
		    [list $::math::exact::szer \
			 [[my applyM $::math::exact::iszer] ref]]
	    } else {
		set absorbed_ [my absorb]
		set signAndMagnitude_ [$absorbed_ getSignAndMagnitude]
		[lindex $signAndMagnitude_ 1] ref
	    }
	}
	return $signAndMagnitude_
    }

    # The 'getLeadingDigitAndRest' method accepts a flag for whether
    # a digit must be extracted (1) or a rational number may be returned
    # directly (0). It returns a two-element list: a digit matrix, which
    # is one of $dpos, $dneg or $dzer, and an exact real representing
    # the number by which the given digit matrix must be postmultiplied.
    method getLeadingDigitAndRest {needDigit} {
	if {![info exists leadingDigitAndRest_]} {
	    if {[my refinesM $::math::exact::idpos]} {
		set leadingDigitAndRest_ \
		    [list $::math::exact::dpos \
			 [[my applyM $::math::exact::idpos] ref]]
	    } elseif {[my refinesM $::math::exact::idneg]} {
		set leadingDigitAndRest_ \
		    [list $::math::exact::dneg \
			 [[my applyM $::math::exact::idneg] ref]]
	    } elseif {[my refinesM $::math::exact::idzer]} {
		set leadingDigitAndRest_ \
		    [list $::math::exact::dzer \
			 [[my applyM $::math::exact::idzer] ref]]
	    } else {
		set absorbed_ [my absorb]
		set newval $absorbed_
		$newval ref
		set leadingDigitAndRest_ \
		    [$newval getLeadingDigitAndRest $needDigit]
		if {[llength $leadingDigitAndRest_] >= 2} {
		    [lindex $leadingDigitAndRest_ 1] ref
		}
		$newval unref
	    }
	}
	return $leadingDigitAndRest_
    }

    # getInterval --
    #	Accumulates 'nDigits' digit matrices, and returns their product,
    #	which is a matrix representing the interval that the digits represent.
    method getInterval {nDigits} {
	lassign [my getSignAndMagnitude] interval e
	$e ref
	lassign [$e getLeadingDigitAndRest 1] ld f
	set interval [math::exact::mdotm $interval $ld]
	$f ref; $e unref; set e $f
	set d $ld
	while {[incr nDigits -1] > 0} {
	    lassign [$e getLeadingDigitAndRest 1] d f
	    set interval [math::exact::mdotm $interval $d]
	    $f ref; $e unref; set e $f
	}
	$e unref
	return $interval
    }

    # asReal --
    #	Coerces an object from rational to real
    #
    # Parameters:
    #	None.
    #
    # Results:
    #	Returns this object
    method asReal {} {self object}

    # asFloat --
    #	Represents this number in E format, after accumulating 'relDigits'
    #	digit matrices.
    method asFloat {relDigits} {
	set v [[my asReal] ref]
	set result [math::exact::mAsFloat [$v getInterval $relDigits]]
	$v unref
	return $result
    }

    # asPrint --
    #	Represents this number for printing. Represents rationals exactly,
    #   others after accumulating 'relDigits' digit matrices.
    method asPrint {relDigits} {
	tailcall math::exact::mAsFloat [my getInterval $relDigits]
    }

    # Derived classes are expected to implement the following methods:
    # method dump {} {
    #	# Formats the object for debugging
    #	# Returns the formatted string
    # }
    method dump {} {
	error "[info object class [self object]] does not implement the 'dump' method."
    }

    # method refinesM {m} {
    #	# Returns 1 if premultiplying by the matrix m refines this object
    #   # Returns 0 otherwise
    # }
    method refinesM {m} {
	error "[info object class [self object]] does not implement the 'refinesM' method."
    }

    # method applyM {m} {
    #	# Premultiplies this object by the matrix m
    # }
    method applyM {m} {
	error "[info object class [self object]] does not implement the 'applyM' method."
    }

    # method applyTLeft {t r} {
    # 	# Computes the left product of the tensor t with this object, and
    #	# applies the result to the right operand r.
    #	# Returns a new exact real representing the product
    # }
    method applyTLeft {t r} {
	error "[info object class [self object]] does not implement the 'applyTLeft' method."
    }

    # method applyTRight {t l} {
    # 	# Computes the right product of the tensor t with this object, and
    #	# applies the result to the left operand l.
    #	# Returns a new exact real representing the product
    # }
    method applyTRight {t l} {
	error "[info object class [self object]] does not implement the 'applyTRight' method."
    }

    # method absorb {} {
    #	# Absorbs the next subexpression or digit into this expression
    #	# Returns the result of absorption, which always represents a
    #	# smaller interval than this expression
    # }
    method absorb {} {
	error "[info object class [self object]] does not implement the 'absorb' method."
    }

    # U- --
    #
    #   Unary - applied to this object
    #
    # Results:
    #	Returns the negation.

    method U- {} {
	my ref
	lassign [my getSignAndMagnitude] sA mA
	set m [math::exact::mdotm {{-1 0} {0 1}} $sA]
	set result [math::exact::Mstrict new $m $mA]
	my unref
	return $result
    }; export U-

    # + --
    #	Adds this object to another.
    #
    # Parameters:
    #	r - Right addend
    #
    # Results:
    #	Returns the sum
    #
    # Either object may be rational (an instance of V) or real (any other
    # Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method + {r} {
	return [$r E+ [self object]]
    }; export +

    # E+ --
    #	Adds two exact reals.
    #
    # Parameters:
    #	l - Left addend
    #
    # Results:
    #	Returns the sum.
    #
    # Neither object is an instance of V (that is, neither is a rational).
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E+ {l} {
	tailcall math::exact::+real $l [self object]
    }; export E+

    # V+ --
    #	Adds a rational and an exact real
    #
    # Parameters:
    #	l - Left addend
    #
    # Results:
    #	Returns the sum.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method V+ {l} {
	tailcall math::exact::+real $l [self object]
    }; export V+

    # - --
    #	Subtracts another object from this object
    #
    # Parameters:
    #	r - Subtrahend
    #
    # Results:
    #	Returns the difference
    #
    # Either object may be rational (an instance of V) or real (any other
    # Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method - {r} {
	return [$r E- [self object]]
    }; export -

    # E- --
    #	Subtracts this exact real from another
    #
    # Parameters:
    #	l - Minuend
    #
    # Results:
    #	Returns the difference
    #
    # Neither object is an instance of V (that is, neither is a rational).
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E- {l} {
	tailcall math::exact::-real $l [self object]
    }; export E-

    # V- --
    #	Subtracts this exact real from a rational
    #
    # Parameters:
    #	l - Minuend
    #
    # Results:
    #	Returns the difference
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method V- {l} {
	tailcall math::exact::-real $l [self object]
    }; export V-

    # * --
    #	Multiplies this object by another.
    #
    # Parameters:
    #	r - Right argument to the multiplication
    #
    # Results:
    #	Returns the product
    #
    # Either object may be rational (an instance of V) or real (any other
    # Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method * {r} {
	return [$r E* [self object]]
    }; export *

    # E* --
    #	Multiplies two exact reals.
    #
    # Parameters:
    #	l - Left argument to the multiplication
    #
    # Results:
    #	Returns the product.
    #
    # Neither object is an instance of V (that is, neither is a rational).
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E* {l} {
	tailcall math::exact::*real $l [self object]
    }; export E*

    # V* --
    #	Multiplies a rational and an exact real
    #
    # Parameters:
    #	l - Left argument to the multiplication
    #
    # Results:
    #	Returns the product.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method V* {l} {
	tailcall math::exact::*real $l [self object]
    }; export V*

    # / --
    #	Divides this object by another.
    #
    # Parameters:
    #	r - Divisor
    #
    # Results:
    #	Returns the quotient
    #
    # Either object may be rational (an instance of V) or real (any other
    # Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method / {r} {
	return [$r E/ [self object]]
    }; export /

    # E/ --
    #	Divides two exact reals.
    #
    # Parameters:
    #	l - Dividend
    #
    # Results:
    #	Returns the quotient.
    #
    # Neither object is an instance of V (that is, neither is a rational).
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E/ {l} {
	tailcall math::exact::/real $l [self object]
    }; export E/

    # V/ --
    #	Divides a rational by an exact real
    #
    # Parameters:
    #	l - Dividend
    #
    # Results:
    #	Returns the product.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method V/ {l} {
	tailcall math::exact::/real $l [self object]
    }; export V/

    # ** -
    #	Raises an exact real to a power
    #
    # Parameters:
    #	r - Exponent
    #
    # Results:
    #	Returns the power.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method ** {r} {
	tailcall $r E** [self object]
    }; export **

    # E** -
    #	Raises an exact real to the power of an exact real
    #
    # Parameters:
    #	l - Base to exponentiate
    #
    # Results:
    #	Returns the power
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E** {l} {
	# This doesn't work as a tailcall, because this object could have
	# been destroyed by the time we're trying to invoke the tailcall,
	# and that will keep command names from resolving because the
	# tailcall mechanism will try to find them in the destroyed namespace.
	return [math::exact::function::exp \
		    [my * [math::exact::function::log $l]]]
    }; export E**

    # V** -
    #	Raises a rational to the power of an exact real
    #
    # Parameters:
    #	l - Base to exponentiate
    #
    # Results:
    #	Returns the power
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method V** {l} {
	# This doesn't work as a tailcall, because this object could have
	# been destroyed by the time we're trying to invoke the tailcall,
	# and that will keep command names from resolving because the
	# tailcall mechanism will try to find them in the destroyed namespace.
	return [math::exact::function::exp \
		    [my * [math::exact::function::log $l]]]
    }; export V**

    # sqrt --
    #
    #	Create an expression representing the square root of an exact
    #	real argument.
    #
    # Results:
    #	Returns the square root.
    #
    # This procedure is a Consumer with respect the the argument and a
    # Constructor with respect to the result, returning a zero-reference
    # result.

    method sqrt {} {
	variable ::math::exact::isneg
	variable ::math::exact::idzer
	variable ::math::exact::idneg
	variable ::math::exact::idpos

	# The algorithm is a modified Newton-Raphson from the Potts and
	# Menissier-Morain papers. The algorithm for sqrt(x) converges
	# rapidly only if x is close to 1, so we rescale to make sure that
	# x is between 1/3 and 3. Specifically:
	# - if x is known to be negative (that is, if $idneg refines it)
	#   then error.
	# - if x is close to 1, $idzer refines it, and we can calculate the
	#   square root directly.
	# - if x is less than 1, $idneg refines it, and we calculate sqrt(4*x)
	#   and multiply by 1/2.
	# - if x is greater than 1, $idpos refines it, and we calculate
	#   sqrt(x/4) and multiply by 2.
	# - if none of the above hold, we have insufficient information about
	#   the magnitude of x and perform a digit exchange.

	my ref
	if {[my refinesM $isneg]} {
	    # Negative argument is an error
	    return -code error -errorcode {MATH EXACT SQRTNEGATIVE} \
		"sqrt of negative argument"
	} elseif {[my refinesM $idzer]} {
	    # Argument close to 1
	    set res [::math::exact::SqrtWorker new [self object]]
	} elseif {[my refinesM $idneg]} {
	    # Small argument - multiply by 4 and halve the square root
	    set y [[my applyM {{4 0} {0 1}}] ref]
	    set z [[$y sqrt] ref]
	    set res [$z applyM {{1 0} {0 2}}]
	    $z unref
	    $y unref
	} elseif {[my refinesM $idpos]} {
	    # Large argument - divide by 4 and double the square root
	    set y [[my applyM {{1 0} {0 4}}] ref]
	    set z [[$y sqrt] ref]
	    set res [$z applyM {{2 0} {0 1}}]
	    $z unref
	    $y unref
	} else {
	    # Unclassified argyment. Perform a digit exchange and try again.
	    set y [[my absorb] ref]
	    set res [$y sqrt]
	    $y unref
	}
	my unref
	return $res
    }
}

# math::exact::V --
#	Vector object
#
# A vector object represents a rational number. It is always strict; no
# methods need to perform lazy evaluation.

oo::class create math::exact::V {
    superclass math::exact::Expression

    # v_ is the vector represented.
    variable v_

    # Constructor accepts the vector as a two-element list {n d}
    # where n is by convention the numerator and d the denominator.
    # It is expected that either n or d is nonzero, and that gcd(n,d) == 0.
    # It is also expected that the fraction will be in lowest terms.
    constructor {v} {
	next
	set v_ $v
    }

    # Destructor need only update reference counts
    destructor {
	next
    }

    # If a rational is acceptable, getLeadingDigitAndRest may simply return
    # this object.
    method getLeadingDigitAndRest {needDigit} {
	if {$needDigit} {
	    return [next $needDigit]
	} else {
	    # Note that the result MUST NOT be memoized, as that would lead
	    # to a circular reference, breaking the refcount system.
	    return [self object]
	}
    }

    # Print this object
    method dump {} {
	return "V($v_)"
    }

    # Test if the vector refines when premultiplied by a matrix
    method refinesM {m} {
	return [math::exact::vrefines [math::exact::mdotv $m $v_]]
    }

    # Apply a matrix to the vector.
    # Precondition: v is in lowest terms

    method applyM {m} {
	set d [math::exact::determinant $m]
	if {$d < 0} { set d [expr {-$d}] }
	if {($d & ($d-1)) != 0} {
	    return [math::exact::V new \
			[math::exact::vreduce [math::exact::mdotv $m $v_]]]
	} else {
	    return [math::exact::V new \
			[math::exact::vscale [math::exact::mdotv $m $v_]]]
	}
    }

    # Left-multiply a tensor t by the vector, and apply the result to
    # an expression 'r'
    method applyTLeft {t r} {
	set u [math::exact::mscale [math::exact::tleftv $t $v_]]
	set det [math::exact::determinant $u]
	if {$det < 0} { set det [expr {-$det}] }
	if {($det & ($det-1)) == 0} {
	    # determinant is a power of 2
	    set res [$r applyM $u]
	    return $res
	} else {
	    return [math::exact::Mstrict new $u $r]
	}
    }

    # Right-multiply a tensor t by the vector, and apply the result
    # to an expression 'l'
    method applyTRight {t l} {
	set u [math::exact::mscale [math::exact::trightv $t $v_]]
	set det [math::exact::determinant $u]
	if {$det < 0} { set det [expr {-$det}] }
	if {($det & ($det-1)) == 0} {
	    # determinant is a power of 2
	    set res [$l applyM $u]
	    return $res
	} else {
	    return [math::exact::Mstrict new $u $l]
	}
    }

    # Get the vector components
    method getV {} {
	return $v_
    }

    # Get the (zero-width) interval that the vector represents.
    method getInterval {nDigits} {
	return [list $v_ $v_]
    }

    # Absorb more information
    method absorb {} {
	# Nothing should ever call this, because a vector's information is
	# already complete.
	error "cannot absorb anything into a vector"
    }

    # asReal --
    #	Coerces an object from rational to real
    #
    # Parameters:
    #	None.
    #
    # Results:
    #	Returns this object converted to an exact real.
    method asReal {} {
	my ref
	lassign [my getSignAndMagnitude] s m
	set result [math::exact::Mstrict new $s $m]
	my unref
	return $result
    }

    # U- --
    #
    #   Unary - applied to this object
    #
    # Results:
    #	Returns the negation.

    method U- {} {
	my ref
	lassign $v_ p q
	set result [math::exact::V new [list [expr {-$p}] $q]]
	my unref
	return $result
    }; export U-

    # + --
    #	Adds a vector to another object
    #
    # Parameters:
    #	r - Right addend
    #
    # Results:
    #	Returns the sum
    #
    # The right-hand addend may be rational (an instance of V) or real
    # (any other Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method + {r} {
	return [$r V+ [self object]]
    }; export +

    # E+ --
    #	Adds an exact real and a vector
    #
    # Parameters:
    #	l - Left addend
    #
    # Results:
    #	Returns the sim.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E+ {l} {
	tailcall math::exact::+real $l [self object]
    }; export E+

    # V+ --
    #	Adds two rationals
    #
    # Parameters:
    #	l - Rational multiplicand
    #
    # Results:
    #	Returns the product.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.
    method V+ {l} {
	my ref
	$l ref
	lassign [$l getV] a b
	lassign $v_ c d
	$l unref
	my unref
	return [math::exact::V new \
		    [math::exact::vreduce \
			 [list [expr {$a*$d+$b*$c}] [expr {$b*$d}]]]]
    }; export V+

    # - --
    #	Subtracts another object from a vector
    #
    # Parameters:
    #	r - Subtrahend
    #
    # Results:
    #	Returns the difference
    #
    # The right-hand operand may be rational (an instance of V) or real
    # (any other Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method - {r} {
	return [$r V- [self object]]
    }; export -

    # E- --
    #	Subtracts this exact real from a rational
    #
    # Parameters:
    #	l - Left addend
    #
    # Results:
    #	Returns the difference.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E- {l} {
	tailcall math::exact::-real $l [self object]
    }; export E-

    # V- --
    #	Subtracts this rational from another
    #
    # Parameters:
    #	l - Rational minuend
    #
    # Results:
    #	Returns the difference.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.
    method V- {l} {
	my ref
	$l ref
	lassign [$l getV] a b
	lassign $v_ c d
	$l unref
	my unref
	return [math::exact::V new \
		    [math::exact::vreduce \
			 [list [expr {$a*$d-$b*$c}] [expr {$b*$d}]]]]
    }; export V-

    # * --
    #	Multiplies a rational by another object
    #
    # Parameters:
    #	r - Right-hand factor
    #
    # Results:
    #	Returns the difference
    #
    # The right-hand operand may be rational (an instance of V) or real
    # (any other Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method * {r} {
	return [$r V* [self object]]
    }; export *

    # E* --
    #	Multiplies an exact real and a rational
    #
    # Parameters:
    #	l - Multiplicand
    #
    # Results:
    #	Returns the product.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E* {l} {
	tailcall math::exact::*real $l [self object]
    }; export E*

    # V* --
    #	Multiplies two rationals
    #
    # Parameters:
    #	l - Rational multiplicand
    #
    # Results:
    #	Returns the product.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.
    method V* {l} {
	my ref
	$l ref
	lassign [$l getV] a b
	lassign $v_ c d
	$l unref
	my unref
	return [math::exact::V new \
		    [math::exact::vreduce \
			 [list [expr {$a*$c}] [expr {$b*$d}]]]]
    }; export V*

    # / --
    #	Divides this object by another.
    #
    # Parameters:
    #	r - Divisor
    #
    # Results:
    #	Returns the quotient
    #
    # Either object may be rational (an instance of V) or real (any other
    # Expression).
    #
    # This method is a Consumer with respect to the current object and to r.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method / {r} {
	return [$r V/ [self object]]
    }; export /

   # E/ --
    #	Divides an exact real and a rational
    #
    # Parameters:
    #	l - Dividend
    #
    # Results:
    #	Returns the quotient.
    #
    # The divisor is not a rationa.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E/ {l} {
	tailcall math::exact::/real $l [self object]
    }; export E/

    # V/ --
    #	Divides two rationals
    #
    # Parameters:
    #	l - Dividend
    #
    # Results:
    #	Returns the quotient.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.
    method V/ {l} {
	my ref
	$l ref
	lassign [$l getV] a b
	lassign $v_ c d
	set result [math::exact::V new \
			[math::exact::vreduce \
			     [list [expr {$a*$d}] [expr {$b*$c}]]]]
	$l unref
	my unref
	return $result
    }; export V/

    # ** -
    #	Raises a rational to a power
    #
    # Parameters:
    #	r - Exponent
    #
    # Results:
    #	Returns the power.
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method ** {r} {
	tailcall $r V** [self object]
    }; export **

    # E** -
    #	Raises an exact real to a rational power
    #
    # Parameters:
    #	l - Base to exponentiate
    #
    # Results:
    #	Returns the power
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method E** {l} {

	# Extract numerator and demominator of the exponent, and consume the
	# exponent.
	my ref
	lassign $v_ c d
	my unref

	# Normalize the sign of the exponent
	if {$d < 0} {
	    set c [expr {-$c}]
	    set d [expr {-$d}]
	}

	# Don't choke if somehow a 0/0 gets here.
	if {$c == 0 && $d == 0} {
	    $l unref
	    return -code error -errorcode "MATH EXACT ZERODIVZERO" \
		"zero divided by zero"
	}

	# Handle integer powers
	if {$d == 1} {
	    return [math::exact::real**int $l $c]
	}

	# Other rational powers come here.
	# We know that $d > 0, and we're not just doing
	# exponentiation by an integer

	return [math::exact::real**rat $l $c $d]
    }; export E**

    # V** -
    #	Raises a rational base to a rational power
    #
    # Parameters:
    #	l - Base to exponentiate
    #
    # Results:
    #	Returns the power
    #
    # This method is a Consumer with respect to the current object and to l.
    # It is a Constructor with respect to its result, returning a zero-ref
    # object.

    method V** {l} {

	# Extract the numerator and denominator of the base and consume
	# the base.
	$l ref
	lassign [$l getV] a b
	$l unref

	# Extract numerator and demominator of the exponent, and consume the
	# exponent.
	my ref
	lassign $v_ c d
	my unref

	# Normalize the signs of the arguments
	if {$b < 0} {
	    set a [expr {-$a}]
	    set b [expr {-$b}]
	}
	if {$d < 0} {
	    set c [expr {-$c}]
	    set d [expr {-$d}]
	}

	# Don't choke if somehow a 0/0 gets here.
	if {$a == 0 && $b == 0 || $c == 0 && $d == 0} {
	    return -code error -errorcode "MATH EXACT ZERODIVZERO" \
		"zero divided by zero"
	}

	# b >= 0 and d >= 0

	if {$a == 0} {
	    if {$c == 0} {
		return -code error -errorcode "MATH EXACT ZEROPOWZERO" \
		    "zero to zero power"
	    } elseif {$d == 0} {
		return -code error -errorcode "MATH EXACT ZEROPOWINF" \
		    "zero to infinite power"
	    } else {
		return [math::exact::V new {0 1}]
	    }
	}

	# a != 0, b >= 0, d >= 0

	if {$b == 0} {
	    if {$c == 0} {
		return -code error -errorcode "MATH EXACT INFPOWZERO" \
		    "infinity to zero power"
	    } elseif {$c < 0} {
		return [math::exact::V new {0 1}]
	    } else {
		return [math::exact::V new {1 0}]
	    }
	}

	# a != 0, b > 0, d >= 0

	if {$c == 0} {
	    return [math::exact::V new {1 1}]
	}

	# handle integer exponents

	if {$d == 1} {
	    return [math::exact::rat**int $a $b $c]
	}

	# a != 0, b > 0, c != 0, d >= 0

	return [math::exact::rat**rat $a $b $c $d]
    }; export V**

    # sqrt --
    #
    #	Calculates the square root of this object
    #
    # Results:
    #	Returns the square root as an exact real.
    #
    # This method is a Consumer with respect to this object and a Constructor
    # with respect to the result, returning a zero-ref object.
    method sqrt {} {
	my ref
	if {([lindex $v_ 0] < 0) ^ ([lindex $v_ 1] < 0)} {
	    return -code error -errorCode "MATH EXACT SQRTNEGATIVE" \
		{square root of negative argument}
	}
	set result [::math::exact::Sqrtrat new {*}$v_]
	my unref
	return $result
    }

}

# math::exact::M --
#	Expression consisting of a matrix times another expression
#
# The matrix {a c} {b d} represents the homography (a*x + b) / (c*x + d).
#
# The inner expression may need to be evaluated lazily. Whether evaluation
# is strict or lazy, the 'e' method will return the expression.

oo::class create math::exact::M {
    superclass math::exact::Expression

    # m_ is the matrix; e_ the inner expression; absorbed_ a cache of the
    # result of the 'absorb' method.
    variable m_ e_ absorbed_

    # constructor accepts the matrix only. The expression is managed in
    # derived classes.
    constructor {m} {
	next
	set m_ $m
    }

    # destructor deletes the memoized expression if one has been stored.
    # The base class destructor handles cleaning up the result of 'absorb'
    destructor {
	if {[info exists e_]} {
	    $e_ unref
	}
	next
    }

    # Test if the matrix refines when premultiplied by another matrix n
    method refinesM {n} {
	return [math::exact::mrefines [math::exact::mdotm $n $m_]]
    }

    # Premultiply the matrix by another matrix n
    method applyM {n} {
	set d [math::exact::determinant $n]
	if {$d < 0} {set d [expr {-$d}]}
	if {($d & ($d-1)) != 0} {
	    return [math::exact::Mstrict new \
			[math::exact::mreduce [math::exact::mdotm $n $m_]] \
			[my e]]
	} else {
	    return [math::exact::Mstrict new \
			[math::exact::mscale [math::exact::mdotm $n $m_]] \
			[my e]]
	}
    }

    # Compute the left product of a tensor t with this matrix, and
    # apply the resulting tensor to the expression 'r'.
    method applyTLeft {t r} {
	return [math::exact::Tstrict new \
		    [math::exact::tscale [math::exact::tleftm $t $m_]] \
		    1 [my e] $r]
    }

    # Compute the right product of a tensor t with this matrix, and
    # apply the resulting tensor to the expression 'l'.
    method applyTRight {t l} {
	return [math::exact::Tstrict new \
		    [math::exact::tscale [math::exact::trightm $t $m_]] \
		    0 $l [my e]]
    }

    # Absorb a digit into this matrix.
    method absorb {} {
	if {![info exists absorbed_]} {
	    set absorbed_ [[[my e] applyM $m_] ref]
	}
	return $absorbed_
    }

    # Derived classes are expected to implement:
    # method e {} {
    #	# Returns the expression to which this matrix is applied.
    #	# Optionally memoizes the result in $e_.
    # }
    method e {} {
	error "[info object class [self object]] does not implement the 'e' method."
    }
}

# math::exact::Mstrict --
#
#	Expression representing the product of a matrix and another
#	expression.
#
# In this version of the class, the expression is known in advance -
# evaluated strictly.

oo::class create math::exact::Mstrict {
    superclass math::exact::M

    # m_ is the matrix.
    # e_ is the expression
    # absorbed_ caches the result of the 'absorb' method.
    variable m_ e_ absorbed_

    # Constructor accepts the matrix and the expression to which
    # it applies.
    constructor {m e} {
	next $m
	set e_ [$e ref]
    }

    # All the heavy lifting of destruction is performed in the base class.
    destructor {
	next
    }

    # The 'e' method returns the expression.
    method e {} {
	return $e_
    }

    # The 'dump' method formats this object for debugging.
    method dump {} {
	return "M($m_,[$e_ dump])"
    }
}

# math::exact::T --
#	Expression representing a 2x2x2 tensor of the third order,
#	applied to two subexpressions.

oo::class create math::exact::T {
    superclass math::exact::Expression

    # t_ - the tensor
    # i_ A flag indicating whether the next 'absorb' should come from the
    #    left (0) or the right (1).
    # l_ - the left subexpression
    # r_ - the right subexpression
    # absorbed_ - the result of an 'absorb' operation

    variable t_ i_ l_ r_ absorbed_

    # constructor accepts the tensor and the initial state for absorption
    constructor {t i} {
	next
	set t_ $t
	set i_ $i
    }

    # destructor removes cached items.
    destructor {
	if {[info exists l_]} {
	    $l_ unref
	}
	if {[info exists r_]} {
	    $r_ unref
	}
	next;			# The base class will clean up absorbed_
    }

    # refinesM --
    #
    #	Tests if this tensor refines when premultiplied by a matrix
    #
    # Parameters:
    #	m - matrix to test
    #
    # Results:
    #	Returns a Boolean indicator that is true if the product refines.

    method refinesM {m} {
	return [math::exact::trefines [math::exact::mdott $m $t_]]
    }

    # applyM --
    #
    #	Left multiplies this tensor by a matrix
    #
    # Parameters:
    #	m - Matrix to multiply
    #
    # Results:
    #	Returns the product
    #
    # This operation has the side effect of making the product strict at
    # the uppermost level, by calling [my l] [my r] to instantiate the
    # subexpressions.

    method applyM {m} {
	set d [math::exact::determinant $m]
	if {$d < 0} {set d [expr {-$d}]}
	if {($d & ($d-1)) != 0} {
	    return [math::exact::Tstrict new \
			[math::exact::treduce [math::exact::mdott $m $t_]] \
			0 [my l] [my r]]
	} else {
	    return [math::exact::Tstrict new \
			[math::exact::tscale [math::exact::mdott $m $t_]] \
			0 [my l] [my r]]
	}
    }

    # absorb --
    #
    #	Absorbs information from the subexpressions.
    #
    # Results:
    #	Returns a copy of the current object, with information from
    #   at least one subexpression absorbed so that more information is
    #	immediately available.

    method absorb {} {
	if {![info exists absorbed_]} {
	    if {[math::exact::trefines $t_]} {
		lassign [math::exact::trans $t_] m n
		set side [math::exact::mdisjointm $m $n]
	    } else {
		set side $i_
	    }
	    if {$side} {
		set absorbed_ [[[my r] applyTRight $t_ [my l]] ref]
	    } else {
		set absorbed_ [[[my l] applyTLeft $t_ [my r]] ref]
	    }
	}
	return $absorbed_
    }

    # applyTRight --
    #
    #	Right-multiplies a tensor by this expression
    #
    # Results:
    #	Returns 't' left-product l right-product $r_.

    method applyTRight {t l} {
	# This is the hard case of digit exchange. We have to
	# get the leading digit from this tensor, absorbing as
	# necessary, right-multiply it into the tensor $t, and
	# compose the new object.
	#
	# Note that unless 'rest' is empty, 'ld' is a digit matrix,
	# so we need to check only for powers of 2 when reducing to
	# lowest terms
	lassign [my getLeadingDigitAndRest 0] ld rest
	if {$rest eq {}} {
	    set u [math::exact::mreduce [math::exact::trightv $t $ld]]
	    return [math::exact::Mstrict new $u $l]
	} else {
	    set u [math::exact::tscale [math::exact::trightm $t $ld]]
	    return [math::exact::Tstrict new $u 0 $l $rest]
	}
    }

    # applyTLeft --
    #
    #	Left-multiplies a tensor by this expression
    #
    # Results:
    #	Returns 't' left-product $l_ right-product 'r'
    method applyTLeft {t r} {
	# This is the hard case of digit exchange. We have to
	# get the leading digit from this tensor, absorbing as
	# necessary, left-multiply it into the tensor $t, and
	# compose the new object
	#
	# Note that unless 'rest' is empty, 'ld' is a digit matrix,
	# so we need to check only for powers of 2 when reducing to
	# lowest terms
	lassign [my getLeadingDigitAndRest 0] ld rest
	if {$rest eq {}} {
	    set u [math::exact::mreduce [math::exact::tleftv $t $ld]]
	    return [math::exact::Mstrict $u $r]
	} else {
	    set u [math::exact::tscale [math::exact::tleftm $t $ld]]
	    return [math::exact::Tstrict new $u 1 $rest $r]
	}
    }

    # Derived classes are expected to implement the following:
    # l --
    #
    #	Returns the left operand
    method l {} {
	error "[info object class [self object]] does not implement the 'l' method"
    }

    # r --
    #
    #	Returns the right operand
    method r {} {
	error "[info object class [self object]] does not implement the 'r' method"
    }

}

# math::exact::Tstrict --
#
#	A strict tensor - one where the subexpressions are both known in
#	advance.

oo::class create math::exact::Tstrict {
    superclass math::exact::T

    # t_ - the tensor
    # i_ A flag indicating whether the next 'absorb' should come from the
    #    left (0) or the right (1).
    # l_ - the left subexpression
    # r_ - the right subexpression
    # absorbed_ - the result of an 'absorb' operation

    variable t_ i_ l_ r_ absorbed_

    # constructor accepts the tensor, the absorption state, and the
    # left and right operands.
    constructor {t i l r} {
	next $t $i
	set l_ [$l ref]
	set r_ [$r ref]
    }

    # base class handles all cleanup
    destructor {
	next
    }

    # l --
    #
    #	Returns the left operand
    method l {} {
	return $l_
    }

    # r --
    #
    #	Returns the right operand
    method r {} {
	return $r_
    }

    # dump --
    #
    #	Formats this object for debugging
    method dump {} {
	return T($t_,$i_\;[$l_ dump],[$r_ dump])
    }
}

# math::exact::opreal --
#
#	Applies a bihomography (bilinear fractional transformation)
#	to two expressions.
#
# Parameters:
#	op - Tensor {{{a b} {c d}} {{e f} {g h}}} representing the operation
#	x - left operand
#	y - right operand
#
# Results:
#	Returns an expression that represents the form:
#	(axy + cx + ey + g) / (bxy + dx + fy + h)
#
# Notes:
#	Note that the four basic arithmetic operations are included here.
#	In addition, this procedure may be used to craft other useful
#	transformations. For example, (1 - u**2) / (1 + u**2)
#	could be constructed as [opreal {{{-1 1} {0 0}} {{0 0} {1 1}}} $u $u]

proc ::math::exact::opreal {op x y {kludge {}}} {
    # split x and y into sign and magnitude
    $x ref; $y ref
    lassign [$x getSignAndMagnitude] sx mx
    lassign [$y getSignAndMagnitude] sy my
    $mx ref; $my ref
    $x unref; $y unref
    set t [tleftm [trightm $op $sy] $sx]
    set r [math::exact::Tstrict new $t 0 $mx $my]
    $mx unref; $my unref
    return $r
}

# math::exact::+real --
# math::exact::-real --
# math::exact::*real --
# math::exact::/real --
#
#	Sum, difference, product and quotient of exact reals
#
# Parameters:
#	x - First operand
#	y - Second operand
#
# Results:
#	Returns x+y, x-y, x*y or x/y as requested.

proc ::math::exact::+real {a b} { variable tadd; return [opreal $tadd $a $b] }
proc ::math::exact::-real {a b} { variable tsub; return [opreal $tsub $a $b] }
proc ::math::exact::*real {a b} { variable tmul; return [opreal $tmul $a $b] }
proc ::math::exact::/real {a b} { variable tdiv; return [opreal $tdiv $a $b] }

# real --
#
#	Coerce an argument to exact-real (possibly from rational)
#
# Parameters:
#	x - Argument to coerce.
#
# Results:
#	Returns the argument coerced to a real.
#
# This operation either does nothing and returns its argument, or is a
# Consumer with respect to its argument and a Constructor with respect to
# its result.

proc ::math::exact::function::real {x} {
    tailcall $x asReal
}

# SqrtWorker --
#
#	Class to calculate the square root of a real.


oo::class create math::exact::SqrtWorker {
    superclass math::exact::T
    variable l_ r_

    # e - The expression whose square root should be calculated.
    #     e should be between close to 1 for good performance. The
    #     'sqrtreal' procedure below handles the scaling.
    constructor {e} {
	next {{{1 0} {2 1}} {{1 2} {0 1}}} 0
	set l_ [$e ref]
    }
    method l {} {
	return $l_
    }
    method r {} {
	if {![info exists r_]} {
	    set r_ [[math::exact::SqrtWorker new $l_] ref]
	}
	return $r_
    }
    method dump {} {
	return "sqrt([$l_ dump])"
    }
}

# sqrt --
#
#	Returns the square root of a number
#
# Parameters:
#	x - Exact real number whose square root is needed.
#
# Results:
#	Returns the square root as an exact real.
#
# The number may be rational or real. There is a special optimization used
# if the number is rational

proc ::math::exact::function::sqrt {x} {
    tailcall $x sqrt
}

# ExpWorker --
#
#	Class that evaluates the exponential function for small exact reals

oo::class create math::exact::ExpWorker {
    superclass math::exact::T
    variable t_ l_ r_ n_

    # Constructor --
    #
    # Parameters:
    #	e - Argument whose exponential is to be computed. (What is
    #	    actually passed in is S0'(x) = (1+x)/(1-x))
    #	n - Number of the convergent of the continued fraction
    #
    # This class is implemented by expanding the continued fraction
    # as needed for precision. Each successive step becomes a new right
    # subexpression of the tensor product.

    constructor {e {n 0}} {
	next [list \
		  [list \
		       [list [expr {2*$n + 2}] [expr {2*$n + 1}]] \
		       [list [expr {2*$n + 1}] [expr {2*$n}]]] \
		  [list \
		       [list [expr {2*$n}] [expr {2*$n + 1}]] \
		       [list [expr {2*$n + 1}] [expr {2*$n + 2}]]]] 0
	set l_ [$e ref]
	set n_ [expr {$n + 1}]
    }

    # l --
    #
    #	Returns the left subexpression; that is, the argument to the
    #	exponential
    method l {} {
	return $l_
    }

    # r --
    #	Returns the right subexpresison - the next convergent, creating it
    #	if necessary
    method r {} {
	if {![info exists r_]} {
	    set r_ [[math::exact::ExpWorker new $l_ $n_] ref]
	}
	return $r_
    }

    # dump --
    #
    #	Displays this object for debugging
    method dump {} {
	return ExpWorker([$l_ dump],[expr {$n_-1}])
    }
}

# exp --
#
#	Evaluates the exponential function of an exact real
#
# Parameters:
#	x - Quantity to be exponentiated
#
# Results:
#	Returns the exact real function value.
#
# This procedure is a Consumer with respect to its argument and a
# Constructor with respect to its result, returning a zero-ref object.

proc ::math::exact::function::exp {x} {
    variable ::math::exact::iszer
    variable ::math::exact::tmul

    # The continued fraction converges only for arguments between -1 and 1.
    # If $iszer refines the argument, then it is in the correct range and
    # we launch ExpWorker to evaluate the continued fraction. If the argument
    # is outside the range [-1/2..1/2], then we evaluate exp(x/2) and square
    # the result. If neither of the above is true, then we perform a digit
    # exchange to get more information about the magnitude of the argument.

    $x ref
    if {[$x refinesM $iszer]} {
	# Argument's absolute value is small - evaluate the exponential
	set y [$x applyM $iszer]
	set result [ExpWorker new $y]
    } elseif {[$x refinesM {{2 2} {-1 1}}]} {
	# Argument's absolute value is large - evaluate exp(x/2)**2
	set xover2 [$x applyM {{1 0} {0 2}}]
	set expxover2 [exp $xover2]
	set result [*real $expxover2 $expxover2]
    } else {
	# Argument's absolute value is uncharacterized - perform a digit
	# exchange to get more information.
	set result [exp [$x absorb]]
    }
    $x unref
    return $result
}

# LogWorker --
#
#	Helper class for evaluating logarithm of an exact real argument.
#
# The algorithm used is a continued fraction representation from Peter Potts's
# paper. This worker evaluates the second and subsequent convergents. The
# first convergent is in the 'log' procedure below, and follows a different
# pattern from the rest of them.

oo::class create math::exact::LogWorker {
    superclass math::exact::T
    variable t_ l_ r_ n_

    # Constructor -
    #
    # Parameters:
    #	e - Argument whose log is to be extracted
    #   n - Number of the convergent.
    constructor {e {n 1}} {
	next [list \
		  [list \
		       [list $n 0] \
		       [list [expr {2*$n + 1}] [expr {$n+1}]]] \
		  [list \
		       [list [expr {$n + 1}] [expr {2*$n + 1}]] \
		       [list 0 $n]]] 0
	set l_ [$e ref]
	set n_ [expr {$n + 1}]
    }

    # l -
    #	Returns the argument whose log is to be extracted
    method l {} {
	return $l_
    }

    # r -
    #	Returns the next convergent, constructing it if necessary.
    method r {} {
	if {![info exists r_]} {
	    set r_ [[math::exact::LogWorker new $l_ $n_] ref]
	}
	return $r_
    }

    # dump -
    #	Dumps this object for debugging
    method dump {} {
	return LogWorker([$l_ dump],[expr {$n_-1}])
    }
}

# log -
#
#	Calculates the natural logarithm of an exact real argument.
#
# Parameters:
#	x - Quantity whose log is to be extracted.
#
# Results:
#	Returns the logarithm
#
# This procedure is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a zero-ref object.

proc ::math::exact::function::log {x} {
    variable ::math::exact::ispos
    variable ::math::exact::isneg
    variable ::math::exact::idpos
    variable ::math::exact::idneg
    variable ::math::exact::log2

    # If x is between 1/2 and 2, the continued fraction will converge. If
    # y = LogWorker(x), then log(x) = (xy + x - y - 1)/(x + y), and the
    # latter function is a bihomography that can be evaluated by 'opreal'
    # directly.
    #
    # If x is negative, that's an error.
    # If x > 1, idpos will refine it, and we compute log(x/2) + log(2)
    # If x < 1, idneg will refine it, and we compute log(2x) - log(2)
    # If none of the above can be proven, perform a digit exchange and
    # try again.

    $x ref
    if {[$x refinesM {{2 -1} {-1 2}}]} {
	# argument in bounds
	set result [math::exact::opreal {{{1 0} {1 1}} {{-1 1} {-1 0}}} \
			$x \
			[LogWorker new $x]]
    } elseif {[$x refinesM $isneg]} {
	# domain error
        return -code error -errorcode {MATH EXACT LOGNEGATIVE} \
	    "log of negative argument"
    } elseif {[$x refinesM $idpos]} {
	# large argument, reduce it and try again
	set result [+real [function::log [$x applyM {{1 0} {0 2}}]] $log2]
    } elseif {[$x refinesM $idneg]} {
	# small argument, increase it and try again
	set result [-real [function::log [$x applyM {{2 0} {0 1}}]] $log2]
    } else {
	# too little information, perform digit exchange.
	set result [function::log [$x absorb]]
    }
    $x unref
    return $result
}

# TanWorker --
#
#	Auxiliary function for tangent of an exact real argument
#
# This class develops the second and subsequent convergents of the continued
# fraction expansion in Potts's paper
oo::class create math::exact::TanWorker {
    superclass math::exact::T
    variable t_ l_ r_ n_

    # Constructor -
    #
    # Parameters:
    #	e - S0'(x) = (1+x)/(1-x), where we wish to evaluate tan(x).
    #   n - Ordinal position of the convergent
    constructor {e {n 1}} {
	next [list \
		  [list \
		       [list [expr {2*$n + 1}] [expr {2*$n + 3}]] \
		       [list [expr {2*$n - 1}] [expr {2*$n + 1}]]] \
		  [list \
		       [list [expr {2*$n + 1}] [expr {2*$n - 1}]] \
		       [list [expr {2*$n + 3}] [expr {2*$n + 1}]]]] 0
	set l_ [$e ref]
	set n_ [expr {$n + 1}]
    }

    # l -
    #  	Returns the argument S0'(x)
    method l {} {
	return $l_
    }

    # r -
    #	Returns the next convergent, constructing it if necessary
    method r {} {
	if {![info exists r_]} {
	    set r_ [[math::exact::TanWorker new $l_ $n_] ref]
	}
	return $r_
    }

    # dump -
    #	Displays this object for debugging
    method dump {} {
	return TanWorker([$l_ dump],[expr {$n_-1}])
    }
}

# tan --
#	Tangent of an exact real argument
#
# Parameters:
#	x - Quantity whose tangent is to be computed.
#
# Results:
#	Returns the tangent
#
# This procedure is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a zero-ref object.

proc ::math::exact::function::tan {x} {
    variable ::math::exact::iszer

    # If |x| < 1, then we use Potts's formula for the tangent.
    # If |x| > 1/2, then we compute y = tan(x/2) and then use the
    # trig identity tan(x) = 2*y/(1-y**2), recognizing that the latter
    # expression can be expressed as a bihomography applied to y and itself,
    # allowing opreal to do the job.
    # If neither can be proven, we perform a digit exchange to get more
    # information.
    # tan((2*n+1)*pi/2), for n an integer, is a well-behaved pole.
    # In particular, 1/tan(pi/2) will correctly return zero.

    $x ref
    if {[$x refinesM $iszer]} {
	set xx [$x applyM $iszer]
	set result [math::exact::Tstrict new {{{1 2} {1 0}} {{-1 0} {-1 2}}} 0 \
			$xx [TanWorker new $xx]]
    } elseif {[$x refinesM {{2 2} {-1 1}}]} {
	set xover2 [$x applyM {{1 0} {0 2}}]
	set tanxover2 [function::tan $xover2]
	set result [opreal {{{0 -1} {1 0}} {{1 0} {0 1}}} $tanxover2 $tanxover2]
    } else {
	set result [function::tan [$x absorb]]
    }
    $x unref
    return $result
}

# sin --
#	Sine of an exact real argument
#
# Parameters:
#	x - Quantity whose sine is to be computed.
#
# Results:
#	Returns the sine
#
# This procedure is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a zero-ref object.

proc ::math::exact::function::sin {x} {
    $x ref
    set tanxover2 [tan [$x applyM {{1 0} {0 2}}]]
    $x unref
    return [opreal {{{0 1} {1 0}} {{1 0} {0 1}}} $tanxover2 $tanxover2]
}

# cos --
#	Cosine of an exact real argument
#
# Parameters:
#	x - Quantity whose cosine is to be computed.
#
# Results:
#	Returns the cosine
#
# This procedure is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a zero-ref object.

proc ::math::exact::function::cos {x} {
    $x ref
    set tanxover2 [tan [$x applyM {{1 0} {0 2}}]]
    $x unref
    return [opreal {{{-1 1} {0 0}} {{0 0} {1 1}}} $tanxover2 $tanxover2]
}

# AtanWorker --
#
#	Auxiliary function for arctangent of an exact real argument
#
# This class develops the second and subsequent convergents of the continued
# fraction expansion in Potts's paper. The argument lies in [-1,1].

oo::class create math::exact::AtanWorker {
    superclass math::exact::T
    variable t_ l_ r_ n_
    # Constructor -
    #
    # Parameters:
    #	e - S0(x) = (x-1)/(x+1), where we wish to evaluate atan(x).
    #   n - Ordinal position of the convergent
    constructor {e {n 1}} {
	next [list \
		  [list \
		       [list [expr {2*$n + 1}] [expr {$n + 1}]] \
		       [list $n 0]] \
		  [list \
		       [list 0 $n] \
		       [list [expr {$n + 1}] [expr {2*$n + 1}]]]] 0
	set l_ [$e ref]
	set n_ [expr {$n + 1}]
    }

    # l -
    #  	Returns the argument S0(x)
    method l {} {
	return $l_
    }

    # r -
    #	Returns the next convergent, constructing it if necessary
    method r {} {
	if {![info exists r_]} {
	    set r_ [[math::exact::AtanWorker new $l_ $n_] ref]
	}
	return $r_
    }

    # dump -
    #	Displays this object for debugging
    method dump {} {
	return AtanWorker([$l_ dump],[expr {$n_-1}])
    }
}

# atanS0 -
#
#	Evaluates the arctangent of S0(x) = (x-1)/(x+1)
#
# Parameters:
#	x - Exact real argumetn
#
# Results:
#	Returns atan((x-1)/(x+1))
#
# This function is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a 0-reference object.

proc ::math::exact::atanS0 {x} {
    return [opreal {{{1 2} {1 0}} {{-1 0} {-1 2}}} $x [AtanWorker new $x]]
}

# atan -
#
#	Arctangent of an exact real
#
# Parameters:
#	x - Exact real argument
#
# Results:
#	Returns atan(x)
#
# This function is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a 0-reference object.
#
# atan(1/0) is undefined and may cause an infinite loop.

proc ::math::exact::function::atan {x} {

    # TODO - find p/q close to the real number x - can be done by
    #        getting a few digits - and do
    # arctan(p/q + eps) = arctan(p/q) + arctan(q**2*eps/(p*q*eps+p**q+q**2))
    # using [$eps applyM] to compute the argument of the second arctan

    variable ::math::exact::szer
    variable ::math::exact::spos
    variable ::math::exact::sinf
    variable ::math::exact::sneg
    variable ::math::exact::pi

    # Four cases, depending on which octant the arctangent lies in.

    $x ref
    lassign [$x getSignAndMagnitude] signum mag
    $mag ref
    $x unref
    set aS0x [atanS0 $mag]
    $mag unref
    if {$signum eq $szer} {
	# -1 < x < 1
	return $aS0x
    } elseif {$signum eq $spos} {
	# x > 0
	return [opreal {{{0 0} {4 0}} {{1 0} {0 4}}} $aS0x $pi]
    } elseif {$signum eq $sinf} {
	# x < -1 or x > 1
	return [opreal {{{0 0} {2 0}} {{1 0} {0 2}}} $aS0x $pi]
    } elseif {$signum eq $sneg} {
	# x < 0
	return [opreal {{{0 0} {4 0}} {{-1 0} {0 4}}} $aS0x $pi]
    } else {
	# can't happen
	error "wrong sign: $signum"
    }
}

# asinreal -
#
#	Computes the arcsine of an exact real argument.
#
# The arcsine is computed from the arctangent by trigonometric identities
#
# This function is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a 0-reference object.
#
# The function is defined only over the open interval (-1,1). Outside
# that range INCLUDING AT THE ENDPOINTS, it may fail and give an infinite
# loop or stack overflow.

proc ::math::exact::asinreal {x} {
    variable iszer
    variable pi

    # Potts's formula doesn't work here - it's singular at zero,
    # and undefined over negative numbers. But some messing with the
    # algebra gives us:
    #     asin(S0*x) = 2*atan(sqrt(x)) - pi/2
    #                = (4*atan(sqrt(x)) - pi) / 2
    # which is continuous and computable over (-1..1)
    $x ref
    set y [$x applyM $iszer]
    $x unref
    return [opreal {{{0 0} {-1 0}} {{4 0} {0 2}}} \
		$pi \
		[function::atan [function::sqrt $y]]]
}

interp alias {} math::exact::function::asin {} math::exact::asinreal

# acosreal -
#
#	Computes the arccosine of an exact real argument.
#
# The arccosine is computed from the arctangent by trigonometric identities
#
# This function is a Consumer with respect to its argument and a Constructor
# with respect to its result, returning a 0-reference object.
#
# The function is defined only over the open interval (-1,1). Outside
# that range INCLUDING AT THE ENDPOINTS, it may fail and give an infinite
# loop or stack overflow.

proc ::math::exact::acosreal {x} {
    variable iszer
    variable pi
    # Potts's formula doesn't work here - it's singular at zero,
    # and undefined over negative numbers. But some messing with the
    # algebra gives us:
    # acos(S0*x) = pi - 2*atan(sqrt(x))
    $x ref
    set y [$x applyM $iszer]
    $x unref
    return [opreal {{{0 0} {1 0}} {{-2 0} {0 1}}} \
		$pi \
		[function::atan [function::sqrt $y]]]
}

interp alias {} math::exact::function::acos {} math::exact::acosreal

# sinhreal, coshreal, tanhreal --
#
#	Hyperbolic functions of exact real arguments
#
# Parameter:
#	x - Argument at which to evaluate the function
#
# Results:
#	Return sinh(x), cosh(x), tanh(x), respectively.
#
# These functions are all Consumers with respect to their arguments and
# Constructors with respect to their results, returning zero-ref objects.
#
# The three functions are well defined over all the finite reals, but
# are ill-behaved at infinity.

proc ::math::exact::sinhreal {x} {
    set expx [function::exp $x]
    return [opreal {{{1 0} {0 1}} {{0 1} {-1 0}}} $expx $expx]
}

interp alias {} math::exact::function::sinh {} math::exact::sinhreal

proc ::math::exact::coshreal {x} {
    set expx [function::exp $x]
    return [opreal {{{1 0} {0 1}} {{0 1} {1 0}}} $expx $expx]
}

interp alias {} math::exact::function::cosh {} math::exact::coshreal

proc ::math::exact::tanhreal {x} {
    set expx [function::exp $x]
    return [opreal {{{1 1} {0 0}} {{0 0} {-1 1}}} $expx $expx]
}

interp alias {} math::exact::function::tanh {} math::exact::tanhreal

# asinhreal, acoshreal, atanhreal --
#
#	Inverse hyperbolic functions of exact real arguments
#
# Parameter:
#	x - Argument at which to evaluate the function
#
# Results:
#	Return asinh(x), acosh(x), atanh(x), respectively.
#
# These functions are all Consumers with respect to their arguments and
# Constructors with respect to their results, returning zero-ref objects.
#
# asinh is defined over the entire real number line, with the exception
# of the point at infinity.  acosh is defined over x > 1 (NOT x=1, which
# is singular). atanh is defined over (-1..1) (NOT the endpoints of the
# interval.)

proc ::math::exact::asinhreal {x} {
    # domain (-Inf .. Inf)
    # asinh(x) = log(x + sqrt(x**2 + 1))
    $x ref
    set retval [function::log \
		    [+real $x \
			 [function::sqrt \
			      [opreal {{{1 0} {0 0}} {{0 0} {1 1}}} $x $x]]]]
    $x unref
    return $retval
}

interp alias {} math::exact::function::asinh {} math::exact::asinhreal

proc ::math::exact::acoshreal {x} {
    # domain (1 .. Inf)
    # asinh(x) = log(x + sqrt(x**2 - 1))
    $x ref
    set retval [function::log \
		    [+real $x \
			 [function::sqrt \
			      [opreal {{{1 0} {0 0}} {{0 0} {-1 1}}} $x $x]]]]
    $x unref
    return $retval
}

interp alias {} math::exact::function::acosh {} math::exact::acoshreal

proc ::math::exact::atanhreal {x} {
    # domain (-1 .. 1)
    variable sinf
    #atanh(x) = log(Sinf[x])/2

    $x ref
    set y [$x applyM $sinf]
    $y ref
    $x unref
    set z [function::log $y]
    $z ref
    $y unref
    set retval [$z applyM {{1 0} {0 2}}]
    $z unref
    return $retval
}

interp alias {} math::exact::function::atanh {} math::exact::atanhreal

# EWorker --
#
#	Evaluates the constant 'e' (the base of the natural logarithms
#
# This class is intended to be singleton. It returns 2.71828.... (the
# base of the natural logarithms) as an exact real.

oo::class create math::exact::EWorker {
    superclass math::exact::M
    variable m_ e_ n_

    # Constructor accepts the number of the continuant.

    constructor {{n 0}} {
	set n_ [expr {$n + 1}]
	next [list [list [expr {2*$n + 2}] [expr {2*$n + 1}]] \
		  [list [expr {2*$n + 1}] [expr {2*$n}]]]
    }
    destructor {
	next
    }

    # e -- Returns the next continuant after this one.

    method e {} {
	if {![info exists e_]} {
	    set e_ [[math::exact::EWorker new $n_] ref]
	}
	return $e_
    }

    # Formats this object for debugging

    method dump {} {
	return M($m_,EWorker($n_))
    }
}

# PiWorker --
#
#	Auxiliary object used in evaluating pi.
#
# This class evaluates the second and subsequent continuants in
# Ramanaujan's formula for sqrt(10005)/pi. The Potts paper presents
# the algorithm, almost without commentary.

oo::class create math::exact::PiWorker {
    superclass math::exact::M
    variable m_ e_ n_

    # Constructor accepts the number of the continuant

    constructor {{n 1}} {
	set n_ [expr {$n + 1}]
	set nsq [expr {$n * $n}]
	set n4 [expr {$nsq * $nsq}]
	set b [expr {(2*$n - 1) * (6*$n - 5) * (6*$n - 1)}]
	set c [expr {$b * (545140134 * $n + 13591409)}]
	set d [expr {$b * ($n + 1)}]
	set e [expr {10939058860032000 * $n4}]
	set p [list [expr {$e - $d - $c}] [expr {$e + $d + $c}]]
	set q [list [expr {$e + $d - $c}] [expr {$e - $d + $c}]]
	next [list $p $q]
    }
    destructor {
	next
    }

    # e --
    #
    #	Returns the next continuant after this one

    method e {} {
	if {![info exists e_]} {
	    set e_ [[math::exact::PiWorker new $n_] ref]
	}
	return $e_
    }

    # dump --
    #
    #	Formats this object for debugging
    method dump {} {
	return M($m_,PiWorker($n_))
    }
}

# Log2Worker --
#
#	Auxiliary class for evaluating log(2).
#
# This object represents the constant (1-2*log(2))/(log(2)-1), the
# product of the second, third, ... nth LFT's of the representation of log(2).

oo::class create math::exact::Log2Worker {
    superclass math::exact::M
    variable m_ e_ n_

    # Constructor accepts the number of the continuant
    constructor {{n 1}} {
	set n_ [expr {$n + 1}]
	set a [expr {3*$n + 1}]
	set b [expr {2*$n + 1}]
	set c [expr {4*$n + 2}]
	set d [expr {3*$n + 2}]
	next [list [list $a $b] [list $c $d]]
    }
    destructor {
	next
    }

    # e --
    #
    #	Returns the next continuant after this one.
    method e {} {
	if {![info exists e_]} {
	    set e_ [[math::exact::Log2Worker new $n_] ref]
	}
	return $e_
    }

    # dump --
    #
    #	Displays this object for debugging
    method dump {} {
	return M($m_,Log2Worker($n_))
    }
}

# Sqrtrat --
#
#	Class that evaluates the square root of a rational

oo::class create math::exact::Sqrtrat {
    superclass math::exact::M
    variable m_ e_ a_ b_ c_

    # Constructor accepts the numerator and denominator. The third argument
    # is an intermediate result for the second and later continuants.
    constructor {a b {c {}}} {
	if {$c eq {}} {
	    set c [expr {$a - $b}]
	}
	set d [expr {2*($b-$a) + $c}]
	if {$d >= 0} {
	    next $::math::exact::dneg
	    set a_ [expr {4 * $a}]
	    set b_ $d
	    set c_ $c
	} else {
	    next $::math::exact::dpos
	    set a_ [expr {-$d}]
	    set b_ [expr {4 * $b}]
	    set c_ $c
	}
    }
    destructor {
	next
    }

    # e --
    #
    #	Returns the next continuant after this one.
    method e {} {
	if {![info exists e_]} {
	    set e_ [[math::exact::Sqrtrat new $a_ $b_ $c_] ref]
	}
	return $e_
    }

    # dump --
    #	Formats this object for debugging.

    method dump {} {
	return "M($m_,Sqrtrat($a_,$b_,$c_))"
    }
}

# math::exact::rat**int --
#
#	Service procedure to raise a rational number to an integer power
#
# Parameters:
#	a - Numerator of the rational
#	b - Denominator of the rational
#	n - Power
#
# Preconditions:
#	n is not zero, a is not zero, b is positive.
#
# Results:
#	Returns the power
#
# This procedure is a Consumer with respect to its arguments and a
# Constructor with respect to its result, returning a zero-ref object.

proc ::math::exact::rat**int {a b n} {
    if {$n < 0} {
	return [V new [list [expr {$b**(-$n)}] [expr {$a**(-$n)}]]]
    } elseif {$n > 0} {
	return [V new [list [expr {$a**($n)}] [expr {$b**($n)}]]]
    } else { ;# zero power shouldn't get here
	return [V new {1 1}]
    }
}

# math::exact::rat**rat --
#
#	Service procedure to raise a rational number to a rational power
#
# Parameters:
#	a - Numerator of the base
#	b - Denominator of the base
#	m - Numerator of the exponent
#	n - Denominator of the exponent
#
# Results:
#	Returns the power as an exact real
#
# Preconditions:
#	a != 0, b > 0, m != 0, n > 0
#
# This procedure is a Constructor with respect to its result

proc ::math::exact::rat**rat {a b m n} {

    # It would be attractive to special case this, but the real mechanism
    # works as well for the moment.

    tailcall real**rat [V new [list $a $b]] $m $n
}

# PowWorker --
#
#	Auxiliary class to compute
#		((p/q)**n + b)**(m/n),
#	where 0<m<n are integers, p, q are integers, b is an exact real

oo::class create math::exact::PowWorker {
    superclass math::exact::T

    variable t_ l_ r_ delta_

    # Self-method: start
    #
    #	Sets up to find z**(m/n) (1 <= m < n), with
    #   z = (p/q)**n + y for integers p and q.
    #
    # Parameters:
    #	p - numerator of the estimated nth root
    #	q - denominator of the estimated nth root
    #	y - residual of the quantity whose root is being extracted
    #	m - numerator of the exponent
    #	n - denominator of the exponent (1 <= m < n)
    #
    # Results:
    #	Returns the power, as an exact real.

    self method start {p q y m n} {
	set pm [expr {$p ** $m}]
	set pnmm [expr {$p ** ($n-$m)}]
	set pn [expr {$pm * $pnmm}]
	set qm [expr {$q ** $m}]
	set qnmm [expr {$q ** ($n-$m)}]
	set qn [expr {$qm * $qnmm}]

	set t0 \
	    [list \
		 [list \
		      [list [expr {$m * $qn}] [expr {$n*$pnmm*$qm}]] \
		      [list 0 [expr {($n-$m) * $qn}]]] \
		 [list \
		      [list [expr {2 * $n * $pn}] 0] \
		      [list [expr {2 * ($n-$m) * $pm * $qnmm}] 0]]]
	set t1 \
	    [list \
		 [list \
		      [list [expr {$n * $qn}] [expr {2*$n * $pnmm*$qm}]] \
		      [list 0 [expr {$n * $qn}]]] \
		 [list \
		      [list [expr {4 * $n * $pn}] 0] \
		      [list [expr {2 * $n * $pm * $qnmm}] 0]]]

	set tinit \
	    [list \
		 [list \
		      [list [expr {$m * $qn}] 0] \
		      [list 0 0]] \
		 [list \
		      [list [expr {$n * $pn}] [expr {$n * $pnmm * $qm}]] \
		      [list \
			   [expr {($n-$m) * $pm * $qnmm}] \
			   [expr {($n-$m) * $qn}]]]]
	$y ref
	set result [$y applyTLeft $tinit [my new $t0 $t1 $y]]
	$y unref
	return $result
    }

    # Constructor --
    #
    # Parameters:
    #	t0 - Tensor from the previous iteration
    #	delta - Increment to use
    #	y - Residual
    #
    # The constructor should not be called directly. Instead, the 'start'
    # method should be called to initialize the iteration

    constructor {t0 delta y} {
	set t [math::exact::tadd $t0 $delta]
	next $t 0
	set l_ [$y ref]
	set delta_ $delta
    }

    # l --
    #
    #	Returns the left subexpression: that is, the 'y' parameter
    method l {} {
	return $l_
    }

    # r --
    #
    #	Returns the right subexpression: that is, the next continuant,
    #	creating it if necessary
    method r {} {
	if {![info exists r_]} {
	    set r_ [[math::exact::PowWorker new $t_ $delta_ $l_] ref]
	}
	return $r_
    }

    method dump {} {
	set res "PowWorker($t_,$delta_,[$l_ dump],"
	if {[info exists r_]} {
	    append res [$r_ dump]
	} else {
	    append res ...
	}
	append res ")"
	return $res
    }

}

# math::exact::real**int --
#
#	Service procedure to raise a real number to an integer power.
#
# Parameters:
#	b - Number to exponentiate
#	e - Power to raise b to.
#
# Results:
#	Returns the power.
#
# This procedure is a Consumer with respect to its arguments and a
# Constructor with respect to its result, returning a zero-ref object.

proc ::math::exact::real**int {b e} {

    # Handle a negative power by raising the reciprocal of the base to
    # a positive power
    if {$e < 0} {
	set e [expr {-$e}]
	set b [K [[$b ref] applyM {{0 1} {1 0}}] [$b unref]]
    }

    # Reduce using square-and-add
    $b ref
    set result [V new {1 1}]
    while {$e != 0} {
	if {$e & 1} {
	    set result [$b * $result]
	    set e [expr {$e & ~1}]
	}
	if {$e == 0} break
	set b [K [[$b * $b] ref] [$b unref]]
	set e [expr {$e>>1}]
    }
    $b unref
    return $result
}

# math::exact::real**rat --
#
#	Service procedure to raise a real number to a rational power.
#
# Parameters -
#
#	b - The base to be exponentiated
#	m - The numerator of the power
#	n - The denominator of the power
#
# Preconditions:
#	n > 0
#
# Results:
#	Returns the power.
#
# This procedure is a Consumer with respect to its arguments and a
# Constructor with respect to its result, returning a zero-ref object.

proc ::math::exact::real**rat {b m n} {

    variable isneg
    variable ispos

    # At this point we need to know the sign of b. Try to determine it.
    # (This can be an infinite loop if b is zero or infinite)
    while {1} {
	if {[$b refinesM $ispos]} {
	    break
	} elseif {[$b refinesM $isneg]} {
	    # negative number to rational power. The denominator must be
	    # odd.
	    if {$n % 2 == 0} {
		return -code error -errorCode {MATH EXACT NEGATIVEPOWREAL} \
		    "negative number to real power"
	    } else {
		set b [K [[$b ref] U-] [$b unref]]
		tailcall [math::exact::real**rat $b $m $n] U-
	    }
	} else {
	    # can't determine positive or negative yet
	    $b ref
	    set nextb [$b absorb]
	    set result [math::exact::real**rat $nextb $m $n]
	    $b unref
	    return $result
	}
    }

    # Handle b(-m/n) by taking (1/b)(m/n)
    if {$m < 0} {
	set m [expr {-$m}]
	set b [K [[$b ref] applyM {{0 1} {1 0}}] [$b unref]]
    }

    # Break m/n apart into integer and fractional parts
    set i [expr {$m / $n}]
    set m [expr {$m % $n}]

    # Do the integer part
    $b ref
    set result [real**int $b $i]
    if {$m == 0} {
	# We really shouldn't get here if m/n is an integer, but don't choke
	$b unref
	return $result
    }

    # Come up with a rational approximation for b**(1/n)
    # real: exp(log(b)/n)
    set approx [[math::exact::function::exp \
		     [[math::exact::function::log $b] \
			  * [math::exact::V new [list 1 $n]]]] ref]
    lassign [$approx getSignAndMagnitude] partial rest
    $rest ref
    $approx unref
    while {1} {
	lassign [$rest getLeadingDigitAndRest 0] digit y
	$y ref
	$rest unref
	set partial [math::exact::mscale [math::exact::mdotm $partial $digit]]
	set rest $y
	lassign $partial pq rs
	lassign $pq p q
	lassign $rs r s
	set qrn [expr {($q*$r)**$n}]
	set t1 [expr {$qrn}]
	set t2 [expr {2 * ($p*$s)**$n}]
	set t3 [expr {4 * $qrn}]
	if {$t1 < $t2 && $t2 < $t3} break
    }
    $y unref

    # Get the residual

    lassign [math::exact::vscale [list $r $s]] p q
    set xn [math::exact::V new [list [expr {$p**$n}] [expr {$q**$n}]]]
    set y [$b - $xn]; $b unref

    # Launch a worker process to perform quasi-Newton iteration to refine
    # the result

    set retval [$result * [math::exact::PowWorker start $p $q $y $m $n]]
    return $retval
}

# pi --
#
#	Returns pi as an exact real

proc ::math::exact::function::pi {} {
    variable ::math::exact::pi
    return $pi
}

# e --
#
#	Returns e as an exact real

proc ::math::exact::function::e {} {
    variable ::math::exact::e
    return $e
}

# math::exact::signum1 --
#
#	Tests an argument's sign.
#
# Parameters:
#	x - Exact real number to test.
#
# Results:
#	Returns -1 if x < -1. Returns 1 if x > 1. May return -1, 0 or 1 if
#	-1 <= x <= 1.
#
# Equality of exact reals is not decidable, so a weaker version of comparison
# testing is needed. This function provides the guts of such a thing. It
# returns an approximation to the signum function that is exact for
# |x| > 1, and arbitrary for |x| < 1.
#
# A typical use would be to replace a test p < q with a test that
# looks like signum1((p-q) / epsilon) == -1. This test is decidable,
# and becomes a test that is true if p < q - epsilon, false if p > q+epsilon,
# and indeterminate if p lies within epsilon of q.  This test is enough for
# most checks for convergence or for selecting a branch of a function.
#
# This function is not decidable if it is not decidable whether x is finite.

proc ::math::exact::signum1 {x} {
    variable ispos
    variable isneg
    variable iszer
    while {1} {
	if {[$x refinesM $ispos]} {
	    return 1
	} elseif {[$x refinesM $isneg]} {
	    return -1
	} elseif {[$x refinesM $iszer]} {
	    return 0
	} else {
	    set x [$x absorb]
	}
    }
}

# math::exact::abs1 -
#
#	Test whether an exact real is 'small' in absolute value.
#
# Parameters:
#	x - Exact real number to test
#
# Results:
#	Returns 0 if |x| is 'close to zero', 1 if |x| is 'far from zero'
#	and either 0, or 1 if |x| is close to 1.
#
# This function is another useful comparator for convergence testing.
# It returns a three-way indication:
#	|x| < 1/2 : 0
#	|x| > 1 : 1
#	1/2 <= |x| <= 2 : May return -1, 0, 1
#
# This function is useful for convergence testing, where it is desired
# to know whether a given value has an absolute value less than a given
# tolerance.

proc ::math::exact::abs1 {x} {
    variable iszer
    while 1 {
	if {[$x refinesM $iszer]} {
	    return 0
	} elseif {[$x refinesM {{2 1} {-2 1}}]} {
	    return 1
	} else {
	    set x [$x absorb]
	}
    }
}

namespace eval ::math::exact {

    # Constant vectors, matrices and tensors

    ;				# the identity matrix
    variable identity		{{ 1  0} { 0  1}}
    ;				# sign matrices for exact floating point
    variable spos		$identity
    variable sinf		{{ 1 -1} { 1  1}}
    variable sneg		{{ 0  1} {-1  0}}
    variable szer		{{ 1  1} {-1  1}}

    ;				# inverses of the sign matrices
    variable ispos		[reverse $spos]
    variable isinf		[reverse $sinf]
    variable isneg		[reverse $sneg]
    variable iszer		[reverse $szer]

    ;				# digit matrices for exact floating point
    variable dneg		{{ 1  1} { 0  2}}
    variable dzer		{{ 3  1} { 1  3}}
    variable dpos		{{ 2  0} { 1  1}}

    ;				# inverses of the digit matrices
    variable idneg 		[reverse $dneg]
    variable idzer		[reverse $dzer]
    variable idpos		[reverse $dpos]

    ;				# aritmetic operators as tensors
    variable tadd		{{{ 0  0} { 1  0}} {{ 1  0} { 0  1}}}
    variable tsub		{{{ 0  0} { 1  0}} {{-1  0} { 0  1}}}
    variable tmul		{{{ 1  0} { 0  0}} {{ 0  0} { 0  1}}}
    variable tdiv		{{{ 0  0} { 1  0}} {{ 0  1} { 0  0}}}

    proc init {} {

	# Variables for fundamental constants e, pi, log2

	variable e [[EWorker new] ref]

	set worker \
	    [[math::exact::Mstrict new {{6795705 213440} {6795704 213440}} \
		  [math::exact::PiWorker new]] ref]
	variable pi [[/real [function::sqrt [V new {10005 1}]] $worker] ref]
	$worker unref

	set worker [[Log2Worker new] ref]
	variable log2 [[$worker applyM {{1 1} {1 2}}] ref]
	$worker unref

    }
    init
    rename init {}

    namespace export exactexpr abs1 signum1
}

package provide math::exact 1.0.1

#-----------------------------------------------------------------------
