# rational_funcs.tcl --
#    Implement procedures to deal with rational functions
#

package require math::polynomials

namespace eval ::math::rationalfunctions {
    variable count 0  ;# Count the number of specific commands
    namespace eval v {}

    namespace export rationalFunction ratioCmd evalRatio \
                     coeffsNumerator coeffsDenominator \
                     derivRatio  \
                     addRatio    subRatio multRatio \
                     divRatio

    namespace import ::math::polynomials::*
}


# rationalFunction --
#    Return a rational function definition
#
# Arguments:
#    num          The coefficients of the numerator
#    den          The coefficients of the denominator
# Result:
#    Rational function definition
#
proc ::math::rationalfunctions::rationalFunction {num den} {

    foreach coeffs [list $num $den] {
        foreach coeff $coeffs {
            if { ! [string is double -strict $coeff] } {
                return -code error "Coefficients must be real numbers"
            }
        }
    }

    #
    # The leading coefficient must be non-zero
    #
    return [list RATIONAL_FUNCTION [polynomial $num] [polynomial $den]]
}

# ratioCmd --
#    Return a procedure that implements a rational function evaluation
#
# Arguments:
#    num          The coefficients of the numerator
#    den          The coefficients of the denominator
# Result:
#    New procedure
#
proc ::math::rationalfunctions::ratioCmd {num {den {}}} {
    variable count

    if { [llength $den] == 0 } {
        if { [lindex $num 0] == "RATIONAL_FUNCTION" } {
            set den [lindex $num 2]
            set num [lindex $num 1]
        }
    }

    set degree1 [expr {[llength $num]-1}]
    set degree2 [expr {[llength $num]-1}]
    set body "expr \{([join $num +\$x*(][string repeat ) $degree1])/\
(double([join $den +\$x*(][string repeat ) $degree2])\}"

    incr count
    set name "::math::rationalfunctions::v::RATIO$count"
    proc $name {x} $body
    return $name
}

# evalRatio --
#    Evaluate a rational function at a given coordinate
#
# Arguments:
#    ratio        Rational function definition
#    x            Coordinate
# Result:
#    Value at x
#
proc ::math::rationalfunctions::evalRatio {ratio x} {
    if { [lindex $ratio 0] != "RATIONAL_FUNCTION" } {
        return -code error "Not a rational function"
    }
    if { ! [string is double $x] } {
        return -code error "Coordinate must be a real number"
    }

    set num 0.0
    foreach c [lindex [lindex $ratio 1] 1] {
        set num [expr {$num*$x+$c}]
    }

    set den 0.0
    foreach c [lindex [lindex $ratio 2] 1] {
        set den [expr {$den*$x+$c}]
    }
    return [expr {$num/double($den)}]
}

# coeffsNumerator --
#    Return the coefficients of the numerator
#
# Arguments:
#    ratio        Rational function definition
# Result:
#    The coefficients in ascending order
#
proc ::math::rationalfunctions::coeffsNumerator {ratio} {
    if { [lindex $ratio 0] != "RATIONAL_FUNCTION" } {
        return -code error "Not a rational function"
    }
    set polyn [lindex $ratio 1]
    return [allCoeffsPolyn $polyn]
}

# coeffsDenominator --
#    Return the coefficients of the denominator
#
# Arguments:
#    ratio        Rational function definition
# Result:
#    The coefficients in ascending order
#
proc ::math::rationalfunctions::coeffsDenominator {ratio} {
    if { [lindex $ratio 0] != "RATIONAL_FUNCTION" } {
        return -code error "Not a rational function"
    }
    set polyn [lindex $ratio 2]
    return [allCoeffsPolyn $polyn]
}

# derivRatio --
#    Return the derivative of the rational function
#
# Arguments:
#    polyn        Polynomial definition
# Result:
#    The new polynomial
#
proc ::math::rationalfunctions::derivRatio {ratio} {
    if { [lindex $ratio 0] != "RATIONAL_FUNCTION" } {
        return -code error "Not a rational function"
    }
    set num_polyn [lindex $ratio 1]
    set den_polyn [lindex $ratio 2]
    set num_deriv [derivPolyn $num_polyn]
    set den_deriv [derivPolyn $den_polyn]
    set num       [subPolyn [multPolyn $num_deriv $den_polyn] \
                            [multPolyn $den_deriv $num_polyn] ]
    set den       [multPolyn $den_polyn $den_polyn]

    return [list RATIONAL_FUNCTION $num $den]
}

# addRatio --
#    Add two rational functions and return the result
#
# Arguments:
#    ratio1       First rational function or a scalar
#    ratio2       Second rational function or a scalar
# Result:
#    The sum of the two functions
# Note:
#    TODO: Check for the same denominator
#
proc ::math::rationalfunctions::addRatio {ratio1 ratio2} {
    if { [llength $ratio1] == 1 && [string is double -strict $ratio1] } {
        set polyn1 [rationalFunction $ratio1 1.0]
    }
    if { [llength $ratio2] == 1 && [string is double -strict $ratio2] } {
        set ratio2 [rationalFunction $ratio1 1.0]
    }
    if { [lindex $ratio1 0] != "RATIONAL_FUNCTION" ||
         [lindex $ratio2 0] != "RATIONAL_FUNCTION" } {
        return -code error "Both arguments must be rational functions or a real number"
    }

    set num1    [lindex $ratio1 1]
    set den1    [lindex $ratio1 2]
    set num2    [lindex $ratio2 1]
    set den2    [lindex $ratio2 2]

    set newnum  [addPolyn [multPolyn $num1 $den2] \
                          [multPolyn $num2 $den1] ]

    set newden  [multPolyn $den1 $den2]

    return [list RATIONAL_FUNCTION $newnum $newden]
}

# subRatio --
#    Subtract two rational functions and return the result
#
# Arguments:
#    ratio1       First rational function or a scalar
#    ratio2       Second rational function or a scalar
# Result:
#    The difference of the two functions
# Note:
#    TODO: Check for the same denominator
#
proc ::math::rationalfunctions::subRatio {ratio1 ratio2} {
    if { [llength $ratio1] == 1 && [string is double -strict $ratio1] } {
        set polyn1 [rationalFunction $ratio1 1.0]
    }
    if { [llength $ratio2] == 1 && [string is double -strict $ratio2] } {
        set ratio2 [rationalFunction $ratio1 1.0]
    }
    if { [lindex $ratio1 0] != "RATIONAL_FUNCTION" ||
         [lindex $ratio2 0] != "RATIONAL_FUNCTION" } {
        return -code error "Both arguments must be rational functions or a real number"
    }

    set num1    [lindex $ratio1 1]
    set den1    [lindex $ratio1 2]
    set num2    [lindex $ratio2 1]
    set den2    [lindex $ratio2 2]

    set newnum  [subPolyn [multPolyn $num1 $den2] \
                          [multPolyn $num2 $den1] ]

    set newden  [multPolyn $den1 $den2]

    return [list RATIONAL_FUNCTION $newnum $newden]
}

# multRatio --
#    Multiply two rational functions and return the result
#
# Arguments:
#    ratio1       First rational function or a scalar
#    ratio2       Second rational function or a scalar
# Result:
#    The product of the two functions
# Note:
#    TODO: Check for the same denominator
#
proc ::math::rationalfunctions::multRatio {ratio1 ratio2} {
    if { [llength $ratio1] == 1 && [string is double -strict $ratio1] } {
        set polyn1 [rationalFunction $ratio1 1.0]
    }
    if { [llength $ratio2] == 1 && [string is double -strict $ratio2] } {
        set ratio2 [rationalFunction $ratio1 1.0]
    }
    if { [lindex $ratio1 0] != "RATIONAL_FUNCTION" ||
         [lindex $ratio2 0] != "RATIONAL_FUNCTION" } {
        return -code error "Both arguments must be rational functions or a real number"
    }

    set num1    [lindex $ratio1 1]
    set den1    [lindex $ratio1 2]
    set num2    [lindex $ratio2 1]
    set den2    [lindex $ratio2 2]

    set newnum  [multPolyn $num1 $num2]
    set newden  [multPolyn $den1 $den2]

    return [list RATIONAL_FUNCTION $newnum $newden]
}

# divRatio --
#    Divide two rational functions and return the result
#
# Arguments:
#    ratio1       First rational function or a scalar
#    ratio2       Second rational function or a scalar
# Result:
#    The quotient of the two functions
# Note:
#    TODO: Check for the same denominator
#
proc ::math::rationalfunctions::divRatio {ratio1 ratio2} {
    if { [llength $ratio1] == 1 && [string is double -strict $ratio1] } {
        set polyn1 [rationalFunction $ratio1 1.0]
    }
    if { [llength $ratio2] == 1 && [string is double -strict $ratio2] } {
        set ratio2 [rationalFunction $ratio1 1.0]
    }
    if { [lindex $ratio1 0] != "RATIONAL_FUNCTION" ||
         [lindex $ratio2 0] != "RATIONAL_FUNCTION" } {
        return -code error "Both arguments must be rational functions or a real number"
    }

    set num1    [lindex $ratio1 1]
    set den1    [lindex $ratio1 2]
    set num2    [lindex $ratio2 1]
    set den2    [lindex $ratio2 2]

    set newnum  [multPolyn $num1 $den2]
    set newden  [multPolyn $num2 $den1]

    return [list RATIONAL_FUNCTION $newnum $newden]
}

#
# Announce our presence
#
package provide math::rationalfunctions 1.0.1

# some tests --
#
if { 0 } {
set prec $::tcl_precision
if {![package vsatisfies [package provide Tcl] 8.5]} {
    set ::tcl_precision 17
} else {
    set ::tcl_precision 0
}


set f1    [::math::rationalfunctions::rationalFunction {1 2 3} {1 4}]
set f2    [::math::rationalfunctions::rationalFunction {1 2 3 0} {1 4}]
set f3    [::math::rationalfunctions::rationalFunction {0 0 0 0} {1}]
set f4    [::math::rationalfunctions::rationalFunction {5 7} {1}]
set cmdf1 [::math::rationalfunctions::ratioCmd {1 2 3} {1 4}]

foreach x {0 1 2 3 4 5} {
    puts "[::math::rationalfunctions::evalRatio $f1 $x] -- \
[expr {(1.0+2.0*$x+3.0*$x*$x)/double(1.0+4.0*$x)}] -- \
[$cmdf1 $x] -- [::math::rationalfunctions::evalRatio $f3 $x]"
}

puts "All coefficients = [::math::rationalfunctions::coeffsNumerator $f2]"
puts "                   [::math::rationalfunctions::coeffsDenominator $f2]"

puts "Derivative = [::math::rationalfunctions::derivRatio $f1]"

puts "Add:       [::math::rationalfunctions::addRatio $f1 $f4]"
puts "Add:       [::math::rationalfunctions::addRatio $f4 $f1]"
puts "Subtract:  [::math::rationalfunctions::subRatio $f1 $f4]"
puts "Multiply:  [::math::rationalfunctions::multRatio $f1 $f4]"

set f1    [::math::rationalfunctions::rationalFunction {1 2 3} 1]
set f2    [::math::rationalfunctions::rationalFunction {0 1} 1]

puts "Divide:    [::math::rationalfunctions::divRatio $f1 $f2]"

set f1    [::math::rationalfunctions::rationalFunction {1 2 3} 1]
set f2    [::math::rationalfunctions::rationalFunction {1 1} {1 2}]

puts "Divide:    [::math::rationalfunctions::divRatio $f1 $f2]"

set f1 [::math::rationalfunctions::rationalFunction {1 2 3} 1]
set f2 [::math::rationalfunctions::rationalFunction {0 1} {0 0 1}]
set f3 [::math::rationalfunctions::divRatio $f2 $f1]
set coeffs [::math::rationalfunctions::coeffsNumerator $f3]
puts "Coefficients: $coeffs"
set f3 [::math::rationalfunctions::divRatio $f1 $f2]
set coeffs [::math::rationalfunctions::coeffsNumerator $f3]
puts "Coefficients: $coeffs"
set f1 [::math::rationalfunctions::rationalFunction {1 2 3} {1 2}]
set f2 [::math::rationalfunctions::rationalFunction {0} {1}]
set f3 [::math::rationalfunctions::divRatio $f2 $f1]
set coeffs [::math::rationalfunctions::coeffsNumerator $f3]
puts "Coefficients: $coeffs"
puts "Eval null function: [::math::rationalfunctions::evalRatio $f2 1]"

set ::tcl_precision $prec
}
