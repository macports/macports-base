# bessel.tcl --
#    Evaluate the most common Bessel functions
#
# TODO:
#    Yn - finding decent approximations seems tough
#    Jnu - for arbitrary values of the parameter
#    J'n - first derivative (from recurrence relation)
#    Kn - forward application of recurrence relation?
#

# namespace special
#    Create a convenient namespace for the "special" mathematical functions
#
namespace eval ::math::special {
    #
    # Define a number of common mathematical constants
    #
    ::math::constants::constants pi

    #
    # Export the functions
    #
    namespace export J0 J1 Jn J1/2 J-1/2 I_n
}

# J0 --
#    Zeroth-order Bessel function
#
# Arguments:
#    x         Value of the x-coordinate
# Result:
#    Value of J0(x)
#
proc ::math::special::J0 {x} {
    Jn 0 $x
}

# J1 --
#    First-order Bessel function
#
# Arguments:
#    x         Value of the x-coordinate
# Result:
#    Value of J1(x)
#
proc ::math::special::J1 {x} {
    Jn 1 $x
}

# Jn --
#    Compute the Bessel function of the first kind of order n
# Arguments:
#    n       Order of the function (must be integer)
#    x       Value of the argument
# Result:
#    Jn(x)
# Note:
#    This relies on the integral representation for
#    the Bessel functions of integer order:
#             1     I pi
#    Jn(x) = --     I   cos(x sin t - nt) dt
#            pi   0 I
#
#    For this kind of integrands the trapezoidal rule is
#    very efficient according to Davis and Rabinowitz
#    (Methods of numerical integration, 1984).
#
proc ::math::special::Jn {n x} {
    variable pi

    if { ![string is integer -strict $n] } {
         return -code error "Order argument must be integer"
    }

    #
    # Integrate over the interval [0,pi] using a small
    # enough step - 40 points should do a good job
    # with |x| < 20, n < 20 (an accuracy of 1.0e-8
    # is reported by Davis and Rabinowitz)
    #
    set number 40
    set step   [expr {$pi/double($number)}]
    set result 0.0

    for { set i 0 } { $i <= $number } { incr i } {
        set t [expr {double($i)*$step}]
        set f [expr {cos($x * sin($t) - $n * $t)}]
        if { $i == 0 || $i == $number } {
            set f [expr {$f/2.0}]
        }
        set result [expr {$result+$f}]
    }

    expr {$result*$step/$pi}
}

# J1/2 --
#    Half-order Bessel function
#
# Arguments:
#    x         Value of the x-coordinate
# Result:
#    Value of J1/2(x)
#
proc ::math::special::J1/2 {x} {
    variable pi
    #
    # This Bessel function can be expressed in terms of elementary
    # functions. Therefore use the explicit formula
    #
    if { $x != 0.0 } {
        expr {sqrt(2.0/$pi/$x)*sin($x)}
    } else {
        return 0.0
    }
}

# J-1/2 --
#    Compute the Bessel function of the first kind of order -1/2
# Arguments:
#    x       Value of the argument (!= 0.0)
# Result:
#    J-1/2(x)
#
proc ::math::special::J-1/2 {x} {
    variable pi
    if { $x == 0.0 } {
        return -code error "Argument must not be zero (singularity)"
    } else {
        return [expr {-cos($x)/sqrt($pi*$x/2.0)}]
    }
}

# I_n --
#    Compute the modified Bessel function of the first kind
#
# Arguments:
#    n            Order of the function (must be positive integer or zero)
#    x            Abscissa at which to compute it
# Result:
#    Value of In(x)
# Note:
#    This relies on Miller's algorithm for finding minimal solutions
#
namespace eval ::math::special {}

proc ::math::special::I_n {n x} {
    if { ! [string is integer $n] || $n < 0 } {
        error "Wrong order: must be positive integer or zero"
    }

    set n2 [expr {$n+8}]  ;# Note: just a guess that this will be enough

    set ynp1 0.0
    set yn   1.0
    set sum  1.0

    while { $n2 > 0 } {
        set ynm1 [expr {$ynp1+2.0*$n2*$yn/$x}]
        set sum  [expr {$sum+$ynm1}]
        if { $n2 == $n+1 } {
           set result $ynm1
        }
        set ynp1 $yn
        set yn   $ynm1
        incr n2 -1
    }

    set quotient [expr {(2.0*$sum-$ynm1)/exp($x)}]

    expr {$result/$quotient}
}

#
# some tests --
#
if { 0 } {
set prec $::tcl_precision
if {![package vsatisfies [package provide Tcl] 8.5]} {
    set ::tcl_precision 17
} else {
    set ::tcl_precision 0
}

foreach x {0.0 2.0 4.4 6.0 10.0 11.0 12.0 13.0 14.0} {
    puts "J0($x) = [::math::special::J0 $x] - J1($x) = [::math::special::J1 $x] \
- J1/2($x) = [::math::special::J1/2 $x]"
}
foreach n {0 1 2 3 4 5} {
    puts [::math::special::I_n $n 1.0]
}

set ::tcl_precision $prec
}
