# polynomials.tcl --
#    Implement procedures to deal with polynomial functions
#
namespace eval ::math::polynomials {
    variable count 0  ;# Count the number of specific commands
    namespace eval v {}

    namespace export polynomial polynCmd evalPolyn \
                     degreePolyn coeffPolyn allCoeffsPolyn \
                     derivPolyn  primitivePolyn \
                     addPolyn    subPolyn multPolyn \
                     divPolyn    remainderPolyn
}


# polynomial --
#    Return a polynomial definition
#
# Arguments:
#    coeffs       The coefficients of the polynomial
# Result:
#    Polynomial definition
#
proc ::math::polynomials::polynomial {coeffs} {

    set rev_coeffs {}
    set degree     -1
    set index       0
    foreach coeff $coeffs {
        if { ! [string is double -strict $coeff] } {
            return -code error "Coefficients must be real numbers"
        }
        set rev_coeffs [concat $coeff $rev_coeffs]
        if { $coeff != 0.0 } {
            set degree $index
        }
        incr index
    }

    #
    # The leading coefficient must be non-zero
    #
    return [list POLYNOMIAL [lrange $rev_coeffs end-$degree end]]
}

# polynCmd --
#    Return a procedure that implements a polynomial evaluation
#
# Arguments:
#    coeffs       The coefficients of the polynomial (or a definition)
# Result:
#    New procedure
#
proc ::math::polynomials::polynCmd {coeffs} {
    variable count

    if { [lindex $coeffs 0] == "POLYNOMIAL" } {
        set coeffs [allCoeffsPolyn $coeffs]
    }

    set degree [expr {[llength $coeffs]-1}]
    set body "expr \{[join $coeffs +\$x*(][string repeat ) $degree]\}"

    incr count
    set name "::math::polynomials::v::POLYN$count"
    proc $name {x} $body
    return $name
}

# evalPolyn --
#    Evaluate a polynomial at a given coordinate
#
# Arguments:
#    polyn        Polynomial definition
#    x            Coordinate
# Result:
#    Value at x
#
proc ::math::polynomials::evalPolyn {polyn x} {
    if { [lindex $polyn 0] != "POLYNOMIAL" } {
        return -code error "Not a polynomial"
    }
    if { ! [string is double $x] } {
        return -code error "Coordinate must be a real number"
    }

    set result 0.0
    foreach c [lindex $polyn 1] {
        set result [expr {$result*$x+$c}]
    }
    return $result
}

# degreePolyn --
#    Return the degree of the polynomial
#
# Arguments:
#    polyn        Polynomial definition
# Result:
#    The degree
#
proc ::math::polynomials::degreePolyn {polyn} {
    if { [lindex $polyn 0] != "POLYNOMIAL" } {
        return -code error "Not a polynomial"
    }
    return [expr {[llength [lindex $polyn 1]]-1}]
}

# coeffPolyn --
#    Return the coefficient of the index'th degree of the polynomial
#
# Arguments:
#    polyn        Polynomial definition
#    index        Degree for which to return the coefficient
# Result:
#    The coefficient of degree "index"
#
proc ::math::polynomials::coeffPolyn {polyn index} {
    if { [lindex $polyn 0] != "POLYNOMIAL" } {
        return -code error "Not a polynomial"
    }
    set coeffs [lindex $polyn 1]
    if { $index < 0 || $index > [llength $coeffs] } {
        return -code error "Index must be between 0 and [llength $coeffs]"
    }
    return [lindex $coeffs end-$index]
}

# allCoeffsPolyn --
#    Return the coefficients of the polynomial
#
# Arguments:
#    polyn        Polynomial definition
# Result:
#    The coefficients in ascending order
#
proc ::math::polynomials::allCoeffsPolyn {polyn} {
    if { [lindex $polyn 0] != "POLYNOMIAL" } {
        return -code error "Not a polynomial"
    }
    set rev_coeffs [lindex $polyn 1]
    set coeffs {}
    foreach c $rev_coeffs {
        set coeffs [concat $c $coeffs]
    }
    return $coeffs
}

# derivPolyn --
#    Return the derivative of the polynomial
#
# Arguments:
#    polyn        Polynomial definition
# Result:
#    The new polynomial
#
proc ::math::polynomials::derivPolyn {polyn} {
    if { [lindex $polyn 0] != "POLYNOMIAL" } {
        return -code error "Not a polynomial"
    }
    set coeffs [lindex $polyn 1]
    set new_coeffs {}
    set idx        [degreePolyn $polyn]
    foreach c [lrange $coeffs 0 end-1] {
        lappend new_coeffs [expr {$idx*$c}]
        incr idx -1
    }
    return [list POLYNOMIAL $new_coeffs]
}

# primitivePolyn --
#    Return the primitive of the polynomial
#
# Arguments:
#    polyn        Polynomial definition
# Result:
#    The new polynomial
#
proc ::math::polynomials::primitivePolyn {polyn} {
    if { [lindex $polyn 0] != "POLYNOMIAL" } {
        return -code error "Not a polynomial"
    }
    set coeffs [lindex $polyn 1]
    set new_coeffs {}
    set idx        [llength $coeffs]
    foreach c [lrange $coeffs 0 end] {
        lappend new_coeffs [expr {$c/double($idx)}]
        incr idx -1
    }
    return [list POLYNOMIAL [concat $new_coeffs 0.0]]
}

# addPolyn --
#    Add two polynomials and return the result
#
# Arguments:
#    polyn1       First polynomial or a scalar
#    polyn2       Second polynomial or a scalar
# Result:
#    The sum of the two polynomials
# Note:
#    Make sure that the first coefficient is not zero
#
proc ::math::polynomials::addPolyn {polyn1 polyn2} {
    if { [llength $polyn1] == 1 && [string is double -strict $polyn1] } {
        set polyn1 [polynomial $polyn1]
    }
    if { [llength $polyn2] == 1 && [string is double -strict $polyn2] } {
        set polyn2 [polynomial $polyn2]
    }
    if { [lindex $polyn1 0] != "POLYNOMIAL" ||
         [lindex $polyn2 0] != "POLYNOMIAL"    } {
        return -code error "Both arguments must be polynomials or a real number"
    }
    set coeffs1 [lindex $polyn1 1]
    set coeffs2 [lindex $polyn2 1]

    set extra1  [expr {[llength $coeffs2]-[llength $coeffs1]}]
    while { $extra1 > 0 } {
        set coeffs1 [concat 0.0 $coeffs1]
        incr extra1 -1
    }

    set extra2  [expr {[llength $coeffs1]-[llength $coeffs2]}]
    while { $extra2 > 0 } {
        set coeffs2 [concat 0.0 $coeffs2]
        incr extra2 -1
    }

    set new_coeffs {}
    foreach c1 $coeffs1 c2 $coeffs2 {
        lappend new_coeffs [expr {$c1+$c2}]
    }
    while { [lindex $new_coeffs 0] == 0.0 } {
        set new_coeffs [lrange $new_coeffs 1 end]
    }
    return [list POLYNOMIAL $new_coeffs]
}

# subPolyn --
#    Subtract two polynomials and return the result
#
# Arguments:
#    polyn1       First polynomial or a scalar
#    polyn2       Second polynomial or a scalar
# Result:
#    The difference of the two polynomials
# Note:
#    Make sure that the first coefficient is not zero
#
proc ::math::polynomials::subPolyn {polyn1 polyn2} {
    if { [llength $polyn1] == 1 && [string is double -strict $polyn1] } {
        set polyn1 [polynomial $polyn1]
    }
    if { [llength $polyn2] == 1 && [string is double -strict $polyn2] } {
        set polyn2 [polynomial $polyn2]
    }
    if { [lindex $polyn1 0] != "POLYNOMIAL" ||
         [lindex $polyn2 0] != "POLYNOMIAL"    } {
        return -code error "Both arguments must be polynomials or a real number"
    }
    set coeffs1 [lindex $polyn1 1]
    set coeffs2 [lindex $polyn2 1]

    set extra1  [expr {[llength $coeffs2]-[llength $coeffs1]}]
    while { $extra1 > 0 } {
        set coeffs1 [concat 0.0 $coeffs1]
        incr extra1 -1
    }

    set extra2  [expr {[llength $coeffs1]-[llength $coeffs2]}]
    while { $extra2 > 0 } {
        set coeffs2 [concat 0.0 $coeffs2]
        incr extra2 -1
    }

    set new_coeffs {}
    foreach c1 $coeffs1 c2 $coeffs2 {
        lappend new_coeffs [expr {$c1-$c2}]
    }
    while { [lindex $new_coeffs 0] == 0.0 } {
        set new_coeffs [lrange $new_coeffs 1 end]
    }
    return [list POLYNOMIAL $new_coeffs]
}

# multPolyn --
#    Multiply two polynomials and return the result
#
# Arguments:
#    polyn1       First polynomial or a scalar
#    polyn2       Second polynomial or a scalar
# Result:
#    The difference of the two polynomials
# Note:
#    Make sure that the first coefficient is not zero
#
proc ::math::polynomials::multPolyn {polyn1 polyn2} {
    if { [llength $polyn1] == 1 && [string is double -strict $polyn1] } {
        set polyn1 [polynomial $polyn1]
    }
    if { [llength $polyn2] == 1 && [string is double -strict $polyn2] } {
        set polyn2 [polynomial $polyn2]
    }
    if { [lindex $polyn1 0] != "POLYNOMIAL" ||
         [lindex $polyn2 0] != "POLYNOMIAL"    } {
        return -code error "Both arguments must be polynomials or a real number"
    }

    set coeffs1 [lindex $polyn1 1]
    set coeffs2 [lindex $polyn2 1]

    #
    # Take care of the null polynomial
    #
    if { $coeffs1 == {} || $coeffs2 == {} } {
        return [polynomial {}]
    }

    set zeros {}
    foreach c $coeffs1 {
        lappend zeros 0.0
    }

    set new_coeffs [lrange $zeros 1 end]
    foreach c $coeffs2 {
        lappend new_coeffs 0.0
    }

    set idx        0
    foreach c $coeffs1 {
        set term_coeffs {}
        foreach c2 $coeffs2 {
            lappend term_coeffs [expr {$c*$c2}]
        }
        set term_coeffs [concat [lrange $zeros 0 [expr {$idx-1}]] \
                                $term_coeffs \
                                [lrange $zeros [expr {$idx+1}] end]]

        set sum_coeffs {}
        foreach t $term_coeffs n $new_coeffs {
            lappend sum_coeffs [expr {$t+$n}]
        }
        set new_coeffs $sum_coeffs
        incr idx
    }

    return [list POLYNOMIAL $new_coeffs]
}

# divPolyn --
#    Divide two polynomials and return the quotient
#
# Arguments:
#    polyn1       First polynomial or a scalar
#    polyn2       Second polynomial or a scalar
# Result:
#    The difference of the two polynomials
# Note:
#    Make sure that the first coefficient is not zero
#
proc ::math::polynomials::divPolyn {polyn1 polyn2} {
    if { [llength $polyn1] == 1 && [string is double -strict $polyn1] } {
        set polyn1 [polynomial $polyn1]
    }
    if { [llength $polyn2] == 1 && [string is double -strict $polyn2] } {
        set polyn2 [polynomial $polyn2]
    }
    if { [lindex $polyn1 0] != "POLYNOMIAL" ||
         [lindex $polyn2 0] != "POLYNOMIAL"    } {
        return -code error "Both arguments must be polynomials or a real number"
    }

    set coeffs1 [lindex $polyn1 1]
    set coeffs2 [lindex $polyn2 1]

    #
    # Take care of the null polynomial
    #
    if { $coeffs1 == {} } {
        return [polynomial {}]
    }
    if { $coeffs2 == {} } {
        return -code error "Denominator can not be zero"
    }

    foreach {quotient remainder} [DivRemPolyn $polyn1 $polyn2] {break}
    return $quotient
}

# remainderPolyn --
#    Divide two polynomials and return the remainder
#
# Arguments:
#    polyn1       First polynomial or a scalar
#    polyn2       Second polynomial or a scalar
# Result:
#    The difference of the two polynomials
# Note:
#    Make sure that the first coefficient is not zero
#
proc ::math::polynomials::remainderPolyn {polyn1 polyn2} {
    if { [llength $polyn1] == 1 && [string is double -strict $polyn1] } {
        set polyn1 [polynomial $polyn1]
    }
    if { [llength $polyn2] == 1 && [string is double -strict $polyn2] } {
        set polyn2 [polynomial $polyn2]
    }
    if { [lindex $polyn1 0] != "POLYNOMIAL" ||
         [lindex $polyn2 0] != "POLYNOMIAL"    } {
        return -code error "Both arguments must be polynomials or a real number"
    }

    set coeffs1 [lindex $polyn1 1]
    set coeffs2 [lindex $polyn2 1]

    #
    # Take care of the null polynomial
    #
    if { $coeffs1 == {} } {
        return [polynomial {}]
    }
    if { $coeffs2 == {} } {
        return -code error "Denominator can not be zero"
    }

    foreach {quotient remainder} [DivRemPolyn $polyn1 $polyn2] {break}
    return $remainder
}

# DivRemPolyn --
#    Divide two polynomials and return the quotient and remainder
#
# Arguments:
#    polyn1       First polynomial or a scalar
#    polyn2       Second polynomial or a scalar
# Result:
#    The difference of the two polynomials
# Note:
#    Make sure that the first coefficient is not zero
#
proc ::math::polynomials::DivRemPolyn {polyn1 polyn2} {

    set coeffs1 [lindex $polyn1 1]
    set coeffs2 [lindex $polyn2 1]

    set steps [expr { [degreePolyn $polyn1] - [degreePolyn $polyn2] + 1 }]

    #
    # Special case: polynomial 1 has lower degree than polynomial 2
    #
    if { $steps <= 0 } {
        return [list [polynomial 0.0] $polyn1]
    } else {
        set extra_coeffs {}
        for { set i 1 } { $i < $steps } { incr i } {
            lappend extra_coeffs 0.0
        }
        lappend extra_coeffs 1.0
    }

    set c2 [lindex $coeffs2 0]
    set quot_coeffs {}

    for { set i 0 } { $i < $steps } { incr i } {
        set c1     [lindex $coeffs1 0]
        set factor [expr {$c1/$c2}]

        set fpolyn [multPolyn $polyn2 \
                              [polynomial [lrange $extra_coeffs $i end]]]

        set newpol [subPolyn $polyn1 [multPolyn $fpolyn $factor]]

        #
        # Due to rounding errors, a very small, parasitical
        # term may still exist. Remove it
        #
        if { [degreePolyn $newpol] == [degreePolyn $polyn1] } {
            set new_coeffs [lrange [allCoeffsPolyn $newpol] 0 end-1]
            set newpol     [polynomial $new_coeffs]
        }
        set polyn1 $newpol
        set coeffs1 [lindex $polyn1 1]
        set quot_coeffs [concat $factor $quot_coeffs]
    }
    set quotient [polynomial $quot_coeffs]

    return [list $quotient $polyn1]
}

#
# Announce our presence
#
package provide math::polynomials 1.0.1

# some tests --
#
if { 0 } {
set prec $::tcl_precision
if {![package vsatisfies [package provide Tcl] 8.5]} {
    set ::tcl_precision 17
} else {
    set ::tcl_precision 0
}

set f1    [::math::polynomials::polynomial {1 2 3}]
set f2    [::math::polynomials::polynomial {1 2 3 0}]
set f3    [::math::polynomials::polynomial {0 0 0 0}]
set f4    [::math::polynomials::polynomial {5 7}]
set cmdf1 [::math::polynomials::polynCmd {1 2 3}]

foreach x {0 1 2 3 4 5} {
    puts "[::math::polynomials::evalPolyn $f1 $x] -- \
[expr {1.0+2.0*$x+3.0*$x*$x}] -- \
[$cmdf1 $x] -- [::math::polynomials::evalPolyn $f3 $x]"
}

puts "Degree: [::math::polynomials::degreePolyn $f1] (expected: 2)"
puts "Degree: [::math::polynomials::degreePolyn $f2] (expected: 2)"
foreach d {0 1 2} {
    puts "Coefficient $d = [::math::polynomials::coeffPolyn $f2 $d]"
}
puts "All coefficients = [::math::polynomials::allCoeffsPolyn $f2]"

puts "Derivative = [::math::polynomials::derivPolyn $f1]"
puts "Primitive  = [::math::polynomials::primitivePolyn $f1]"

puts "Add:       [::math::polynomials::addPolyn $f1 $f4]"
puts "Add:       [::math::polynomials::addPolyn $f4 $f1]"
puts "Subtract:  [::math::polynomials::subPolyn $f1 $f4]"
puts "Multiply:  [::math::polynomials::multPolyn $f1 $f4]"

set f1    [::math::polynomials::polynomial {1 2 3}]
set f2    [::math::polynomials::polynomial {0 1}]

puts "Divide:    [::math::polynomials::divPolyn $f1 $f2]"
puts "Remainder: [::math::polynomials::remainderPolyn $f1 $f2]"

set f1    [::math::polynomials::polynomial {1 2 3}]
set f2    [::math::polynomials::polynomial {1 1}]

puts "Divide:    [::math::polynomials::divPolyn $f1 $f2]"
puts "Remainder: [::math::polynomials::remainderPolyn $f1 $f2]"

set f1 [::math::polynomials::polynomial {1 2 3}]
set f2 [::math::polynomials::polynomial {0 1}]
set f3 [::math::polynomials::divPolyn $f2 $f1]
set coeffs [::math::polynomials::allCoeffsPolyn $f3]
puts "Coefficients: $coeffs"
set f3 [::math::polynomials::divPolyn $f1 $f2]
set coeffs [::math::polynomials::allCoeffsPolyn $f3]
puts "Coefficients: $coeffs"
set f1 [::math::polynomials::polynomial {1 2 3}]
set f2 [::math::polynomials::polynomial {0}]
set f3 [::math::polynomials::divPolyn $f2 $f1]
set coeffs [::math::polynomials::allCoeffsPolyn $f3]
puts "Coefficients: $coeffs"

set ::tcl_precision $prec
}
