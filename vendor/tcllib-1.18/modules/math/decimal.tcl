package require Tcl 8.5
package provide math::decimal 1.0.3
#
# Copyright 2011, 2013 Mark Alston. All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#   1. Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#
#   2. Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in
#      the documentation and/or other materials provided with the distribution.
#
#   THIS SOFTWARE IS PROVIDED BY Mark Alston ``AS IS'' AND ANY EXPRESS
#   OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#   ARE DISCLAIMED. IN NO EVENT SHALL Mark Alston OR CONTRIBUTORS
#   BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#   OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
#   OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#   EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# decimal.tcl --
#
#     Tcl implementation of a General Decimal Arithmetic as defined
#     by the IEEE 754 standard as given on http:://speleotrove.com/decimal
#
#     Decimal numbers are defined as a list of sign mantissa exponent
#
#     The following operations are current implemented:
#
#       fromstr tostr  -- for converting to and from decimal numbers.
#
#       add subtract divide multiply abs compare  -- basic operations
#       max min plus minus copynegate copysign is-zero is-signed
#       is-NaN is-infinite is-finite
#
#       round_half_even round_half_up round_half_down   -- rounding methods
#       round_down round_up round_floor round_ceiling
#       round_05up
#
#     By setting the extended variable to 0 you get the behavior of the decimal
#     subset arithmetic X3.274 as defined on
#     http://speleotrove.com/decimal/dax3274.html#x3274
#
#     This package passes all tests in test suites:
#           http://speleotrove.com/decimal/dectest.html
#      and  http://speleotrove.com/decimal/dectest0.html
#
#      with the following exceptions:
#
#     This version fails some tests that require setting the max
#     or min exponent to force truncation or rounding.
#
#     This version fails some tests which require the sign of zero to be set
#     correctly during rounding
#
#     This version cannot handle sNaN's (Not sure that they are of any use for
#     tcl programmers anyway.
#
#     If you find errors in this code please let me know at
#         mark at beernut dot com
#
# Decimal --
#     Namespace for the decimal arithmetic procedures
#
namespace eval ::math::decimal {
    variable precision 20
    variable maxExponent 999
    variable minExponent -998
    variable tinyExponent [expr {$minExponent - ($precision - 1)}]
    variable rounding half_up
    variable extended 1

    # Some useful variables to set.
    variable zero [list 0 0 0]
    variable one [list 0 1 0]
    variable ten [list 0 1 1]
    variable onehundred [list 0 1 2]
    variable minusone [list 1 1 0]

    namespace export tostr fromstr setVariable getVariable\
	             add + subtract - divide / multiply * \
                     divide-int  remainder \
                     fma fused-multiply-add \
                     plus minus copynegate negate copysign \
                     abs compare max min \
                     is-zero is-signed is-NaN is-infinite is-finite \
                     round_half_even round_half_up round_half_down \
                     round_down round_up round_floor round_ceiling round_05up

}

# setVariable
#     Set the desired variable
#
# Arguments:
#     variable setting
#
# Result:
#     None
#
proc ::math::decimal::setVariable {variable setting} {
    variable rounding
    variable precision
    variable extended
    variable maxExponent
    variable minExponent
    variable tinyExponent

    switch -nocase -- $variable {
	rounding {set rounding $setting}
	precision {set precision $setting}
	extended {set extended $setting}
	maxExponent {set maxExponent $setting}
	minExponent {
	    set minExponent $setting
	    set tinyExponent [expr {$minExponent - ($precision - 1)}]
	}
	default {}
    }
}

# setVariable
#     Set the desired variable
#
# Arguments:
#     variable setting
#
# Result:
#     None
#
proc ::math::decimal::getVariable {variable} {
    variable rounding
    variable precision
    variable extended
    variable maxExponent
    variable minExponent

    switch -- $variable {
	rounding {return $rounding}
	precision {return $precision}
	extended {return $extended}
	maxExponent {return $maxExponent}
	minExponent {return $minExponent}
	default {}
    }
}

# add or +
#     Add two numbers
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     Sum of both (rescaled)
#
proc ::math::decimal::add {a b {rescale 1}} {
    return [+ $a $b $rescale]
}

proc ::math::decimal::+ {a b {rescale 1}} {
    variable extended
    variable rounding
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if {!$extended} {
	if {$ma == 0 } {
	    return $b
	}
	if {$mb == 0 } {
	    return $a
	}
    }

    if { $ma eq "NaN" || $mb eq "NaN" } {
	return [list 0 "NaN" 0]
    }

    if { $ma eq "Inf" || $mb eq "Inf" } {
	if { $ma ne "Inf" } {
	    return $b
	} elseif { $mb ne "Inf" } {
	    return $a
	} elseif { $sb != $sa } {
	    return [list 0 "NaN" 0]
	} else {
	    return $a
	}
    }
	
    if { $ea > $eb } {
        set ma [expr {$ma * 10 ** ($ea-$eb)}]
        set er $eb
    } else {
        set mb [expr {$mb * 10 ** ($eb-$ea)}]
        set er $ea
    }
    if { $sa == $sb } {
	# Both are either postive or negative
	# Sign remains the same.
	set mr [expr {$ma + $mb}]
	set sr $sa
    } else {
	# one is negative and one is positive.
	# Set sign to the same as the larger number
	# and subract the smaller from the larger.
	if { $ma > $mb } {
	    set sr $sa
	    set mr [expr {$ma - $mb}]
	} elseif { $mb > $ma } {
	    set sr $sb
	    set mr [expr {$mb - $ma}]
	} else {
	    if { $rounding == "floor" } {
		set sr 1
	    } else {
		set sr 0
	    }
	    set mr 0
	}
    }
    if { $rescale } {
	return [Rescale [list $sr $mr $er]]
    } else {
	return [list $sr $mr $er]
    }
}

# copynegate --
#     Takes one operand and returns a copy with the sign inverted.
#     In this implementation it works nearly the same as minus
#     but is probably much faster. The main difference is that no
#     rescaling is done.
#
#
# Arguments:
#     a          operand
#
# Result:
#     a with sign flipped
#
proc ::math::decimal::negate { a } {
    return [copynegate $a]
}

proc ::math::decimal::copynegate { a } {
    lset a 0 [expr {![lindex $a 0]}]
    return $a
}

# copysign --
#     Takes two operands and returns a copy of the first with the
#     sign set to the sign of the second.
#
#
# Arguments:
#     a          operand
#     b          operand
#
# Result:
#     b with a's sign
#
proc ::math::decimal::copysign { a b } {
    lset a 0 [lindex $b 0]
    return $a
}

# minus --
#     subtract 0 $a
#
#     Note: does not pass all tests on extended mode.
#
# Arguments:
#     a          operand
#
# Result:
#     0 - $a
#
proc ::math::decimal::minus { a } {
    return [- [list 0 0 0] $a]
}

# plus --
#     add 0 $a
#
#    Note: does not pass all tests on extended mode.
#
# Arguments:
#     a          operand
#
# Result:
#     0 + $a
#
proc ::math::decimal::plus {a} {
    return [+ [list 0 0 0] $a]
}



# subtract or -
#     Subtract two numbers (or unary minus)
#
# Arguments:
#     a          First operand
#     b          Second operand (optional)
#
# Result:
#     Sum of both (rescaled)
#
proc ::math::decimal::subtract {a {b {}} {rescale 1}} {
    return [- $a $b]
}

proc ::math::decimal::- {a {b {}} {rescale 1}} {
    variable extended

    if {!$extended} {
	foreach {sa ma ea} $a {break}
	foreach {sb mb eb} $b {break}
	if {$ma == 0 } {
	    lset b 0 [expr {![lindex $b 0]}]
	    return $b
	}
	if {$mb == 0 } {
	    return $a
	}
    }

    if { $b == {} } {
        lset a 0 [expr {![lindex $a 0]}]
        return $a
    } else {
        lset b 0 [expr {![lindex $b 0]}]
        return [+ $a $b $rescale]
    }
}


# compare
#     Compare two numbers.
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     1 if a is larger than b
#     0 if a is equal to b
#    -1 if a is smaller than b.
#
proc ::math::decimal::compare {a b} {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $sa != $sb } {
	if {$ma != 0 } {
	    set ma 1
	    set ea 0
	} elseif { $mb != 0 } {
	    set mb 1
	    set eb 0
	} else {
	    return 0
	}
    }
    if { $ma eq "Inf" && $mb eq "Inf" } {
	if { $sa == $sb } {
	    return 0
	} elseif { $sa > $sb } {
	    return -1
	} else {
	    return 1
	}
    }

    set comparison [- [list $sa $ma $ea] [list $sb $mb $eb] 0]

    if { [lindex $comparison 0] && [lindex $comparison 1] != 0 } {
	return -1
    } elseif { [lindex $comparison 1] == 0 } {
	return 0
    } else {
	return 1
    }
}

# min
#     Return the smaller of two numbers
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     smaller of a or b
#
proc ::math::decimal::min {a b} {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $sa != $sb } {
	if {$ma != 0 } {
	    set ma 1
	    set ea 0
	} elseif { $mb != 0 } {
	    set mb 1
	    set eb 0
	}
    }
    if { $ma eq "Inf" && $mb eq "Inf" } {
	if { $sa == $sb } {
	    return [list $sa "Inf" 0]
	} else {
	    return [list 1 "Inf" 0]
	}
    }

    set comparison [compare [list $sa $ma $ea] [list $sb $mb $eb]]

    if { $comparison == 1 } {
	return [Rescale $b]
    } elseif { $comparison == -1 } {
	return [Rescale $a]
    } elseif { $sb != $sa } {
	if { $sa } {
	    return [Rescale $a]
	} else {
	    return [Rescale $b]
	}
    } elseif { $sb && $eb > $ea } {
	# Both are negative and the same numerically. So return the one with the largest exponent.
	return [Rescale $b]
    } elseif { $sb }  {
	# Negative with $eb < $ea now.
	return [Rescale $a]
    } elseif { $ea > $eb } {
	# Both are positive so return the one with the smaller
	return [Rescale $b]
    } else {
	return [Rescale $a]
    }
}

# max
#     Return the larger of two numbers
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     larger of a or b
#
proc ::math::decimal::max {a b} {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $sa != $sb } {
	if {$ma != 0 } {
	    set ma 1
	    set ea 0
	} elseif { $mb != 0 } {
	    set mb 1
	    set eb 0
	}
    }
    if { $ma eq "Inf" && $mb eq "Inf" } {
	if { $sa == $sb } {
	    return [list $sa "Inf" 0]
	} else {
	    return [list 0 "Inf" 0]
	}
    }

    set comparison [compare [list $sa $ma $ea] [list $sb $mb $eb]]

    if { $comparison == 1 } {
	return [Rescale $a]
    } elseif { $comparison == -1 } {
	return [Rescale $b]
    } elseif { $sb != $sa } {
	if { $sa } {
	    return [Rescale $b]
	} else {
	    return [Rescale $a]
	}
    } elseif { $sb && $eb > $ea } {
	# Both are negative and the same numerically. So return the one with the smallest exponent.
	return [Rescale $a]
    } elseif { $sb }  {
	# Negative with $eb < $ea now.
	return [Rescale $b]
    } elseif { $ea > $eb } {
	# Both are positive so return the one with the larger exponent
	return [Rescale $a]
    } else {
	return [Rescale $b]
    }
}

# maxmag -- max-magnitude
#     Return the larger of two numbers ignoring their signs.
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     larger of a or b ignoring their signs.
#
proc ::math::decimal::maxmag {a b} {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}


    if { $ma eq "Inf" && $mb eq "Inf" } {
	if { $sa == 0 || $sb == 0 } {
	    return [list 0 "Inf" 0]
	} else {
	    return [list 1 "Inf" 0]
	}
    }

    set comparison [compare [list 0 $ma $ea] [list 0 $mb $eb]]

    if { $comparison == 1 } {
	return [Rescale $a]
    } elseif { $comparison == -1 } {
	return [Rescale $b]
    } elseif { $sb != $sa } {
	if { $sa } {
	    return [Rescale $b]
	} else {
	    return [Rescale $a]
	}
    } elseif { $sb && $eb > $ea } {
	# Both are negative and the same numerically. So return the one with the smallest exponent.
	return [Rescale $a]
    } elseif { $sb }  {
	# Negative with $eb < $ea now.
	return [Rescale $b]
    } elseif { $ea > $eb } {
	# Both are positive so return the one with the larger exponent
	return [Rescale $a]
    } else {
	return [Rescale $b]
    }
}

# minmag -- min-magnitude
#     Return the smaller of two numbers ignoring their signs.
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     smaller  of a or b ignoring their signs.
#
proc ::math::decimal::minmag {a b} {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $ma eq "Inf" && $mb eq "Inf" } {
	if { $sa == 1 || $sb == 1 } {
	    return [list 1 "Inf" 0]
	} else {
	    return [list 0 "Inf" 0]
	}
    }

    set comparison [compare [list 0 $ma $ea] [list 0 $mb $eb]]

    if { $comparison == 1 } {
	return [Rescale $b]
    } elseif { $comparison == -1 } {
	return [Rescale $a]
    } else {
	# They compared the same so now we use a normal comparison including the signs. This is per the specs.
	if { $sa > $sb } {
	    return [Rescale $a]
	} elseif { $sb > $sa } {
	    return [Rescale $b]
	} elseif { $sb && $eb > $ea } {
	    # Both are negative and the same numerically. So return the one with the largest exponent.
	    return [Rescale $b]
	} elseif { $sb }  {
	    # Negative with $eb < $ea now.
	    return [Rescale $a]
	} elseif { $ea > $eb } {
	    return [Rescale $b]
	} else {
	    return [Rescale $a]
	}
    }
}

# fma - fused-multiply-add
#     Takes three operands. Multiplies the first two and then adds the third.
#     Only one rounding (Rescaling) takes place at the end instead of after
#     both the multiplication and again after the addition.
#
# Arguments:
#     a          First operand
#     b          Second operand
#     c          Third operand
#
# Result:
#     (a*b)+c
#
proc ::math::decimal::fused-multiply-add {a b c} {
    return [fma $a $b $c]
}

proc ::math::decimal::fma {a b c} {
    return [+ $c [* $a $b 0]]
}

# multiply or *
#     Multiply two numbers
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     Product of both (rescaled)
#
proc ::math::decimal::multiply {a b {rescale 1}} {
    return [* $a $b $rescale]
}

proc ::math::decimal::* {a b {rescale 1}} {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $ma eq "NaN" || $mb eq "NaN" } {
	return [list 0 "NaN" 0]
    }

    set sr [expr {$sa^$sb}]

    if { $ma eq "Inf" || $mb eq "Inf" } {
	if { $ma == 0 || $mb == 0 } {
	    return [list 0 "NaN" 0]
	} else {
	    return [list $sr "Inf" 0]
	}
    }

    set mr [expr {$ma * $mb}]
    set er [expr {$ea + $eb}]


    if { $rescale } {
	return [Rescale [list $sr $mr $er]]
    } else {
	return [list $sr $mr $er]
    }
}

# divide or /
#     Divide two numbers
#
# Arguments:
#     a          First operand
#     b          Second operand
#
# Result:
#     Quotient of both (rescaled)
#
proc ::math::decimal::divide {a b {rescale 1}} {
    return [/ $a $b]
}

proc ::math::decimal::/ {a b {rescale 1}} {
    variable precision

    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $ma eq "NaN" || $mb eq "NaN" } {
	return [list 0 "NaN" 0]
    }

    set sr [expr {$sa^$sb}]

    if { $ma eq "Inf" } {
	if { $mb ne "Inf"} {
	    return [list $sr "Inf" 0]
	} else {
	    return [list 0 "NaN" 0]
	}
    }

    if { $mb eq "Inf" } {
	if { $ma ne "Inf"} {
	    return [list $sr 0 0]
	} else {
	    return [list 0 "NaN" 0]
	}
    }

    if { $mb == 0 } {
	if { $ma == 0 } {
	    return [list 0 "NaN" 0]
	} else {
	    return [list $sr "Inf" 0]
	}
    }
    set adjust 0
    set mr 0


    if { $ma == 0 } {
	set er [expr {$ea - $eb}]
	return [list $sr 0 $er]
    }
    if { $ma < $mb } {
	while { $ma < $mb } {
	    set ma [expr {$ma * 10}]
	    incr adjust
	}
    } elseif { $ma >= $mb * 10 } {
	while { $ma >= [expr {$mb * 10}] } {
	    set mb [expr {$mb * 10}]
	    incr adjust -1
	}
    }

    while { 1 } {
	while { $mb <= $ma } {
	    set ma [expr {$ma - $mb}]
	    incr mr
	}
	if { ( $ma == 0 && $adjust >= 0 ) || [string length $mr] > $precision + 1 } {
	    break
	} else {
	    set ma [expr {$ma * 10}]
	    set mr [expr {$mr * 10}]
	    incr adjust
	}
    }

    set er [expr {$ea - ($eb + $adjust)}]

    if { $rescale } {
	return [Rescale [list $sr $mr $er]]
    } else {
	return [list $sr $mr $er]
    }
}

# divideint -- Divide integer
#     Divide a by b and return the integer part of the division.
#
#  Basically, if we send a and b to the divideint (which returns i)
#  and remainder function (which returns r) then the following is true:
#      a = i*b + r
#
# Arguments:
#     a          First operand
#     b          Second operand
#
#
proc ::math::decimal::divideint { a b } {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}
    set sr [expr {$sa^$sb}]


	
    if { $sr == 1 } {
	set sign_string "-"
    } else {
	set sign_string ""
    }

    if { ($ma eq "NaN" || $mb eq "NaN") || ($ma == 0 && $mb == 0 ) } {
	return "NaN"
    }

    if { $ma eq "Inf" || $mb eq "Inf" } {
	if { $ma eq $mb } {
	    return "NaN"
	} elseif { $mb eq "Inf" } {
	    return "${sign_string}0"
	} else {
	    return "${sign_string}Inf"
	}
    }

    if { $mb == 0 } {
	return "${sign_string}Inf"
    }
    if { $mb == "Inf" } {
	return "${sign_string}0"
    }
    set adjust [expr {abs($ea - $eb)}]
    if { $ea < $eb } {
	set a_adjust 0
	set b_adjust $adjust
    } elseif { $ea > $eb } {
	set b_adjust 0
	set a_adjust $adjust
    } else {
	set a_adjust 0
	set b_adjust 0
    }

    set integer [expr {($ma*10**$a_adjust)/($mb*10**$b_adjust)}]
    return $sign_string$integer
}

# remainder -- Remainder from integer division.
#     Divide a by b and return the remainder part of the division.
#
#  Basically, if we send a and b to the divideint (which returns i)
#  and remainder function (which returns r) then the following is true:
#      a = i*b + r
#
# Arguments:
#     a          First operand
#     b          Second operand
#
#
proc ::math::decimal::remainder { a b } {
    foreach {sa ma ea} $a {break}
    foreach {sb mb eb} $b {break}

    if { $sa == 1 } {
	set sign_string "-"
    } else {
	set sign_string ""
    }

    if { ($ma eq "NaN" || $mb eq "NaN") || ($ma == 0 && $mb == 0 ) } {
	if { $mb eq "NaN" && $mb ne $ma } {
	    if { $sb == 1 } {
		set sign_string "-"
	    } else {
		set sign_string ""
	    }
	    return "${sign_string}NaN"
	} elseif { $ma eq "NaN" } {
	    return "${sign_string}NaN"
	} else {
	    return "NaN"
	}
    } elseif { $mb == 0 } {
	return "NaN"
    }

    if { $ma eq "Inf" || $mb eq "Inf" } {
	if { $ma eq $mb } {
	    return "NaN"
	} elseif { $mb eq "Inf" } {
	    return [tostr $a]
	} else {
	    return "NaN"
	}
    }

    if { $mb == 0 } {
	return "${sign_string}Inf"
    }
    if { $mb == "Inf" } {
	return "${sign_string}0"
    }

    lset a 0 0
    lset b 0 0
    if { $mb == 0 } {
	return "${sign_string}Inf"
    }
    if { $mb == "Inf" } {
	return "${sign_string}0"
    }

    set adjust [expr {abs($ea - $eb)}]
    if { $ea < $eb } {
	set a_adjust 0
	set b_adjust $adjust
    } elseif { $ea > $eb } {
	set b_adjust 0
	set a_adjust $adjust
    } else {
	set a_adjust 0
	set b_adjust 0
    }

    set integer [expr {($ma*10**$a_adjust)/($mb*10**$b_adjust)}]

    set remainder [tostr [- $a [* [fromstr $integer] $b 0]]]
    return $sign_string$remainder
}


# abs --
#     Returns the Absolute Value of a number
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#
# Result:
#     Absolute value (as a list)
#
 proc ::math::decimal::abs {a} {
     lset a 0 0
     return [Rescale $a]
 }


# Rescale --
#     Rescale the number (using proper rounding)
#
# Arguments:
#     a Number in decimal format
#
# Result:
#     Rescaled number
#
proc ::math::decimal::Rescale { a } {



    variable precision
    variable rounding
    variable maxExponent
    variable minExponent
    variable tinyExponent

    foreach {sign mantisse exponent} $a {break}

    set man_length [string length $mantisse]

    set adjusted_exponent [expr {$exponent + ($man_length -1)}]

    if { $adjusted_exponent < $tinyExponent } {
	set mantisse [lindex [round_$rounding [list $sign $mantisse [expr {abs($tinyExponent) - abs($adjusted_exponent)}]] 0] 1]
	return [list $sign $mantisse $tinyExponent]
    } elseif { $adjusted_exponent > $maxExponent } {
	if { $mantisse  == 0 } {
	    return [list $sign 0 $maxExponent]
	} else {
	    switch -- $rounding {
		half_even -
		half_up { return [list $sign "Inf" 0] }
		down -
		05up {
		    return [list $sign [string repeat 9 $precision] $maxExponent]
		}
		ceiling {
		    if { $sign } {
			return [list $sign [string repeat 9 $precision] $maxExponent]
		    } else {
			return [list 0 "Inf" 0]
		    }
		}
		floor {
		    if { !$sign } {
			return [list $sign [string repeat 9 $precision] $maxExponent]
		    } else {
			return [list 1 "Inf" 0]
		    }
		}
		default { }
	    }
	}
    }

    if { $man_length <= $precision } {
        return [list $sign $mantisse $exponent]
    }

    set  mantisse [lindex [round_$rounding [list $sign $mantisse [expr {$precision - $man_length}]] 0] 1]
    set exponent [expr {$exponent + ($man_length - $precision)}]

    # it is possible now that our rounding gave us a new digit in our mantisse
    # example rounding 999.9 to 1 digits  with precision 3 will give us
    # 1000 back.
    # This can only happen by adding a zero on the end of our mantisse however.
    # So we just chomp it off.

    set man_length_now [string length $mantisse]
    if { $man_length_now > $precision } {
	set mantisse [string range $mantisse 0 end-1]
	incr exponent
	# Check again to see if we have overflowed
        # we change our test to >= because we have incremented exponent.
	if { $adjusted_exponent >= $maxExponent } {
	    switch -- $rounding {
		half_even -
		half_up { return [list $sign "Inf" 0] }
		down -
		05up {
		    return [list $sign [string repeat 9 $precision] $maxExponent]
		}
		ceiling {
		    if { $sign } {
			return [list $sign [string repeat 9 $precision] $maxExponent]
		    } else {
			return [list 0 "Inf" 0]
		    }
		}
		floor {
		    if { !$sign } {
			return [list $sign [string repeat 9 $precision] $maxExponent]
		    } else {
			return [list 1 "Inf" 0]
		    }
		}
		default { }
	    }
	}
    }
    return [list $sign $mantisse $exponent]
}

# tostr --
#     Convert number to string using appropriate method depending on extended
#     attribute setting.
#
# Arguments:
#     number     Number to be converted
#
# Result:
#     Number in the form of a string
#
proc ::math::decimal::tostr { number } {
    variable extended
    switch -- $extended {
	0 { return [tostr_numeric $number] }
	1 { return [tostr_scientific $number] }
    }
}

# tostr_scientific --
#     Convert number to string using scientific notation as called for in
#     Decmath specifications.
#
# Arguments:
#     number     Number to be converted
#
# Result:
#     Number in the form of a string
#
proc ::math::decimal::tostr_scientific {number} {
    foreach {sign mantisse exponent} $number {break}

    if { $sign } {
	set sign_string "-"
    } else {
	set sign_string ""
    }

    if { $mantisse eq "NaN" } {
	return "NaN"
    }
    if { $mantisse eq "Inf" } {
	return ${sign_string}${mantisse}
    }


    set digits [string length $mantisse]
    set adjusted_exponent [expr {$exponent + $digits - 1}]

    # Why -6? Go read the specs on the website mentioned in the header.
    # They choose it, I'm using it. They actually list some good reasons though.
    if { $exponent <= 0 && $adjusted_exponent >= -6 } {
	if { $exponent == 0 } {
	    set string $mantisse
	} else {
	    set exponent [expr {abs($exponent)}]
	    if { $digits > $exponent } {
		set string [string range $mantisse 0 [expr {$digits-$exponent-1}]].[string range $mantisse [expr {$digits-$exponent}] end]	
		set exponent [expr {-$exponent}]	
	    } else {
		set string 0.[string repeat 0 [expr {$exponent-$digits}]]$mantisse
	    }
	}
    } elseif { $exponent <= 0 && $adjusted_exponent < -6 } {
	if { $digits > 1 } {

	    set string [string range $mantisse 0 0].[string range $mantisse 1 end]	

	    set exponent [expr {$exponent + $digits - 1}]	
	    set string "${string}E${exponent}"
	}  else {
	    set string "${mantisse}E${exponent}"
	}
    } else {
	if { $adjusted_exponent >= 0 } {
	    set adjusted_exponent "+$adjusted_exponent"
	}
	if { $digits > 1 } {
	    set string "[string range $mantisse 0 0].[string range $mantisse 1 end]E$adjusted_exponent"
	} else {
	    set string "${mantisse}E$adjusted_exponent"
	}
    }
    return $sign_string$string
}

# tostr_numeric --
#     Convert number to string using the simplified number set conversion
#     from the X3.274 subset of Decimal Arithmetic specifications.
#
# Arguments:
#     number     Number to be converted
#
# Result:
#     Number in the form of a string
#
proc ::math::decimal::tostr_numeric {number} {
    variable precision
    foreach {sign mantisse exponent} $number {break}

    if { $sign } {
	set sign_string "-"
    } else {
	set sign_string ""
    }

    if { $mantisse eq "NaN" } {
	return "NaN"
    }
    if { $mantisse eq "Inf" } {
	return ${sign_string}${mantisse}
    }

    set digits [string length $mantisse]
    set adjusted_exponent [expr {$exponent + $digits - 1}]

    if { $mantisse == 0 } {
	set string 0
	set sign_string ""
    } elseif { $exponent <= 0 && $adjusted_exponent >= -6 } {
	if { $exponent == 0 } {
	    set string $mantisse
	} else {
	    set exponent [expr {abs($exponent)}]
	    if { $digits > $exponent } {
		set string [string range $mantisse 0 [expr {$digits-$exponent-1}]]
		set decimal_part [string range $mantisse [expr {$digits-$exponent}] end]
		set string ${string}.${decimal_part}
		set exponent [expr {-$exponent}]	
	    } else {
		set string 0.[string repeat 0 [expr {$exponent-$digits}]]$mantisse
	    }
	}
    } elseif { $exponent <= 0 && $adjusted_exponent < -6 } {
	if { $digits > 1 } {
	    set string [string range $mantisse 0 0].[string range $mantisse 1 end]	
	    set exponent [expr {$exponent + $digits - 1}]	
	    set string "${string}E${exponent}"
	}  else {
	    set string "${mantisse}E${exponent}"
	}
    } else {
	if { $adjusted_exponent >= 0 } {
	    set adjusted_exponent "+$adjusted_exponent"
	}
	if { $digits > 1 && $adjusted_exponent >= $precision } {
	    set string "[string range $mantisse 0 0].[string range $mantisse 1 end]E$adjusted_exponent"
	} elseif { $digits + $exponent <= $precision } {
	    set string ${mantisse}[string repeat 0 [expr {$exponent}]]
	} else {
	    set string "${mantisse}E$adjusted_exponent"
	}
    }
    return $sign_string$string
}

# fromstr --
#     Convert string to number
#
# Arguments:
#     string      String to be converted
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::fromstr {string} {
    variable extended

    set string [string trim $string "'\""]

    if { [string range $string 0 0] == "-" } {
	set sign 1
	set string [string trimleft $string -]
	incr pos -1
    } else  {
	set sign 0
    }

    if { $string eq "Inf" || $string eq "NaN" } {
	if {!$extended} {
	    # we don't allow these strings in the subset arithmetic.
	    # throw error.
	    error "Infinities and NaN's not allowed in simplified decimal arithmetic"
	} else {
	    return [list $sign $string 0]
	}
    }

    set string [string trimleft $string "+-"]
    set echeck [string first "E" [string toupper $string]]
    set epart 0
    if { $echeck >= 0 } {
	set epart [string range $string [expr {$echeck+1}] end]
	set string [string range $string 0 [expr {$echeck -1}]]
    }

    set pos [string first . $string]

    if { $pos < 0 } {
	if { $string == 0 } {
	    set mantisse 0
	    if { !$extended } {
		set sign 0
	    }
	} else {
	    set mantisse $string
	}
        set exponent 0
    } else {
	if { $string == "" } {
	    return [list 0 0 0]
	} else {
	    #stripping the leading zeros here is required to avoid some octal issues.
	    #However, it causes us to fail some tests with numbers like 0.00 and 0.0
	    #which test differently but we can't deal with now.
	    set mantisse [string trimleft [string map {. ""} $string] 0]
	    if { $mantisse == "" } {
		set mantisse 0
		if {!$extended} {
		    set sign 0
		}
	    }
	    set fraction [string range $string [expr {$pos+1}] end]
	    set exponent [expr {-[string length $fraction]}]
	}
    }
    set exponent [expr {$exponent + $epart}]

    if { $extended } {
	return [list $sign $mantisse $exponent]
    } else {
	return [Rescale [list $sign $mantisse $exponent]]
    }
}

# ipart --
#     Return the integer part of a Decimal Number
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#
#
# Result:
#     Integer
#
proc ::math::decimal::ipart { a } {

    foreach {sa ma ea} $a {break}

    if { $ea == 0 } {
	if { $sa } {
	    return -$ma
	} else {
	    return $ma
	}
    } elseif { $ea > 0 } {
	if { $sa } {
	    return [expr {-1 * $ma * 10**$ea}]
	} else {
	    return [expr {$ma * 10**$ea}]
	}
    } else {
	if { [string length $ma] <= abs($ea) } {
	    return 0
	} else {
	    if { $sa } {
		set string_sign "-"
	    } else {
		set string_sign ""
	    }
	    set ea [expr {abs($ea)}]
	    return "${string_sign}[string range $ma 0 end-$ea]"
	}
    }
}

# round_05_up --
#     Round zero or five away from 0.
#     The same as round-up, except that rounding up only occurs
#     if the digit to be rounded up is 0 or 5, and after overflow
#     the result is the same as for round-down.
#
#     Bias: away from zero
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_05up {a digits} {
    foreach {sa ma ea} $a {break}

    if { -$ea== $digits } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr { $ma * 10**($digits+$ea) }]
	set exponent [expr {-1 * $digits}]
    } else {
	set round_exponent [expr {$digits + $ea}]
	if { [string length $ma] <= $round_exponent } {
	    if { $ma != 0 } {
		set mantissa 1
	    } else {
		set mantissa 0
	    }
	    set exponent 0
	} else {
	    set integer_part [ipart [list 0 $ma $round_exponent]]

	    if { [compare [list 0 $ma $round_exponent] [list 0 ${integer_part}0 -1]] == 0 } {
		# We are rounding something with fractional part .0
		set mantissa  $integer_part
	    } elseif { [string index $integer_part end] eq 0 || [string index $integer_part end] eq 5 } {
		set mantissa [expr {$integer_part + 1}]
	    } else {
		set mantissa  $integer_part
	    }
	    set exponent [expr {-1 * $digits}]
	}
    }
    return [list $sa $mantissa $exponent]
}

# round_half_up --
#
#     Round to the nearest. If equidistant, round up.
#
#
#     Bias: away from zero
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_half_up {a digits} {
    foreach {sa ma ea} $a {break}

    if { $digits + $ea == 0 } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr {$ma *10 **($digits+$ea)}]
    } else {
	set round_exponent [expr {$digits + $ea}]
	set integer_part [ipart [list 0 $ma $round_exponent]]

	switch -- [compare [list 0 $ma $round_exponent] [list 0 ${integer_part}5 -1]] {
	    0 {
		# We are rounding something with fractional part .5
		set mantissa [expr {$integer_part + 1}]
	    }
	    -1 {
		set mantissa $integer_part
	    }
	    1 {
		set mantissa [expr {$integer_part + 1}]
	    }
	
	}
    }
    set exponent [expr {-1 * $digits}]
    return [list $sa $mantissa $exponent]
}

# round_half_even --
#     Round to the nearest. If equidistant, round so the final digit is even.
#     Bias: none
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_half_even {a digits} {

    foreach {sa ma ea} $a {break}

    if { $digits + $ea == 0 } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr {$ma * 10**($digits+$ea)}]
    } else {
	set round_exponent [expr {$digits + $ea}]
	set integer_part [ipart [list 0 $ma $round_exponent]]

	switch -- [compare [list 0 $ma $round_exponent] [list 0 ${integer_part}5 -1]] {
	    0 {
		# We are rounding something with fractional part .5
		if { $integer_part % 2 } {
		    # We are odd so round up
		    set mantissa [expr {$integer_part + 1}]
		} else {
		    # We are even so round down
		    set mantissa $integer_part
		}
	    }
	    -1 {
		set mantissa $integer_part
	    }
	    1 {
		set mantissa [expr {$integer_part + 1}]
	    }
	}
    }
    set exponent [expr {-1 * $digits}]
    return [list $sa $mantissa $exponent]
}

# round_half_down --
#
#     Round to the nearest. If equidistant, round down.
#
#     Bias: towards zero
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_half_down {a digits} {
    foreach {sa ma ea} $a {break}

    if { $digits + $ea == 0 } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr {$ma * 10**($digits+$ea)}]
    } else {
	set round_exponent [expr {$digits + $ea}]
	set integer_part [ipart [list 0 $ma $round_exponent]]
	switch -- [compare [list 0 $ma $round_exponent] [list 0 ${integer_part}5 -1]] {
	    0 {
		# We are rounding something with fractional part .5
		# The rule is to round half down.
		set mantissa $integer_part
	    }
	    -1 {
		set mantissa $integer_part
	    }
	    1 {
		set mantissa [expr {$integer_part + 1}]
	    }
	}
    }
    set exponent [expr {-1 * $digits}]
    return [list $sa $mantissa $exponent]
}

# round_down --
#
#     Round toward 0.  (Truncate)
#
#     Bias: towards zero
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_down {a digits} {
    foreach {sa ma ea} $a {break}


    if { -$ea== $digits } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr { $ma * 10**($digits+$ea) }]
    } else {
	set round_exponent [expr {$digits + $ea}]
	set mantissa [ipart [list 0 $ma $round_exponent]]
    }

    set exponent [expr {-1 * $digits}]
    return [list $sa $mantissa $exponent]
}

# round_floor --
#
#     Round toward -Infinity.
#
#     Bias: down toward -Inf.
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_floor {a digits} {
    foreach {sa ma ea} $a {break}

    if { -$ea== $digits } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr { $ma * 10**($digits+$ea) }]
    } else {
	set round_exponent [expr {$digits + $ea}]
	if { $ma == 0 } {
	    set mantissa 0
	} elseif { !$sa } {
	    set mantissa [ipart [list 0 $ma $round_exponent]]
	} else {
	    set mantissa [expr {[ipart [list 0 $ma $round_exponent]] + 1}]
	}
    }
    set exponent [expr {-1 * $digits}]
    return [list $sa $mantissa $exponent]
}	

# round_up --
#
#     Round away from 0
#
#     Bias: away from 0
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_up {a digits} {
    foreach {sa ma ea} $a {break}


    if { -$ea== $digits } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr { $ma * 10**($digits+$ea) }]
	set exponent [expr {-1 * $digits}]
    } else {
	set round_exponent [expr {$digits + $ea}]
	if { [string length $ma] <= $round_exponent } {
	    if { $ma != 0 } {
		set mantissa 1
	    } else {
		set mantissa 0
	    }
	    set exponent 0
	} else {
	    set integer_part [ipart [list 0 $ma $round_exponent]]
	    switch -- [compare [list 0 $ma $round_exponent] [list 0 ${integer_part}0 -1]] {
		0 {
		    # We are rounding something with fractional part .0
		    set mantissa $integer_part
		}
		default {
		    set mantissa [expr {$integer_part + 1}]
		}
	    }
	    set exponent [expr {-1 * $digits}]
	}
    }
    return [list $sa $mantissa $exponent]
}

# round_ceiling --
#
#     Round toward Infinity
#
#     Bias: up toward Inf.
#
# Arguments:
#     Number in the form of {sign mantisse exponent}
#     Number of decimal points to round to.
#
# Result:
#     Number in the form of {sign mantisse exponent}
#
proc ::math::decimal::round_ceiling {a digits} {
    foreach {sa ma ea} $a {break}
    if { -$ea== $digits } {
	return $a
    } elseif { $digits + $ea > 0 } {
	set mantissa [expr { $ma * 10**($digits+$ea) }]
	set exponent [expr {-1 * $digits}]
    } else {
	set round_exponent [expr {$digits + $ea}]
	if { [string length $ma] <= $round_exponent } {
	    if { $ma != 0 } {
		set mantissa 1
	    } else {
		set mantissa 0
	    }
	    set exponent 0
	} else {
	    set integer_part [ipart [list 0 $ma $round_exponent]]
	    switch -- [compare [list 0 $ma $round_exponent] [list 0 ${integer_part}0 -1]] {
		0 {
		    # We are rounding something with fractional part .0
		    set mantissa $integer_part
		}
		default {
		    if { $sa } {
			set mantissa [expr {$integer_part}]
		    } else {
			set mantissa [expr {$integer_part + 1}]
		    }
		}
	    }
	    set exponent [expr {-1 * $digits}]
	}
    }

    return [list $sa $mantissa $exponent]
}	

# is-finite
#
#     Takes one operand and returns: 1 if neither Inf or Nan otherwise 0.
#
#
# Arguments:
#     a - decimal number
#
# Returns:
#
proc ::math::decimal::is-finite { a } {
    set mantissa [lindex $a 1]
    if { $mantissa == "Inf" || $mantissa == "NaN" } {
	return 0
    } else {
	return 1
    }
}

# is-infinite
#
#     Takes one operand and returns: 1 if Inf otherwise 0.
#
#
# Arguments:
#     a - decimal number
#
# Returns:
#
proc ::math::decimal::is-infinite { a } {
    set mantissa [lindex $a 1]
    if { $mantissa == "Inf" } {
	return 1
    } else {
	return 0
    }
}

# is-NaN
#
#     Takes one operand and returns: 1 if NaN otherwise 0.
#
#
# Arguments:
#     a - decimal number
#
# Returns:
#
proc ::math::decimal::is-NaN { a } {
    set mantissa [lindex $a 1]
    if { $mantissa == "NaN" } {
	return 1
    } else {
	return 0
    }
}

# is-signed
#
#     Takes one operand and returns: 1 if sign is 1 (negative).
#
#
# Arguments:
#     a - decimal number
#
# Returns:
#
proc ::math::decimal::is-signed { a } {
    set sign [lindex $a 0]
    if { $sign } {
	return 1
    } else {
	return 0
    }
}

# is-zero
#
#     Takes one operand and returns: 1 if operand is zero otherwise 0.
#
#
# Arguments:
#     a - decimal number
#
# Returns:
#
proc ::math::decimal::is-zero { a } {
    set mantisse [lindex $a 1]
    if { $mantisse == 0 } {
	return 1
    } else {
	return 0
    }
}
