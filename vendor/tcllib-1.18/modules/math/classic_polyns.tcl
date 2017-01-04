# classic_polyns.tcl --
#    Implement procedures for the classic orthogonal polynomials
#
package require math::polynomials

namespace eval ::math::special {
    if {[info commands addPolyn] == {} } {
        namespace import ::math::polynomials::*
    }
}


# legendre --
#    Return the nth degree Legendre polynomial
#
# Arguments:
#    n            The degree of the polynomial
# Result:
#    Polynomial definition
#
proc ::math::special::legendre {n} {
    if { ! [string is integer -strict $n] || $n < 0 } {
        return -code error "Degree must be a non-negative integer"
    }

    set pnm1   [polynomial 1.0]
    set pn     [polynomial {0.0 1.0}]

    if { $n == 0 } {return $pnm1}
    if { $n == 1 } {return $pn}

    set degree 1
    while { $degree < $n } {
        set an       [expr {(2.0*$degree+1.0)/($degree+1.0)}]
        set bn       0.0
        set cn       [expr {$degree/($degree+1.0)}]
        set factor_n [polynomial [list $bn $an]]
        set term_nm1 [multPolyn $pnm1 [expr {-1.0*$cn}]]
        set term_n   [multPolyn $factor_n $pn]
        set pnp1     [addPolyn $term_n $term_nm1]

        set pnm1     $pn
        set pn       $pnp1
        incr degree
    }

    return $pnp1
}

# chebyshev --
#    Return the nth degree Chebeyshev polynomial of the first kind
#
# Arguments:
#    n            The degree of the polynomial
# Result:
#    Polynomial definition
#
proc ::math::special::chebyshev {n} {
    if { ! [string is integer -strict $n] || $n < 0 } {
        return -code error "Degree must be a non-negative integer"
    }

    set pnm1   [polynomial 1.0]
    set pn     [polynomial {0.0 1.0}]

    if { $n == 0 } {return $pnm1}
    if { $n == 1 } {return $pn}

    set degree 1
    while { $degree < $n } {
        set an       2.0
        set bn       0.0
        set cn       1.0
        set factor_n [polynomial [list $bn $an]]
        set term_nm1 [multPolyn $pnm1 [expr {-1.0*$cn}]]
        set term_n   [multPolyn $factor_n $pn]
        set pnp1     [addPolyn $term_n $term_nm1]

        set pnm1     $pn
        set pn       $pnp1
        incr degree
    }

    return $pnp1
}

# laguerre --
#    Return the nth degree Laguerre polynomial with parameter alpha
#
# Arguments:
#    alpha        The parameter for the polynomial
#    n            The degree of the polynomial
# Result:
#    Polynomial definition
#
proc ::math::special::laguerre {alpha n} {
    if { ! [string is double -strict $alpha] } {
        return -code error "Parameter must be a double"
    }
    if { ! [string is integer -strict $n] || $n < 0 } {
        return -code error "Degree must be a non-negative integer"
    }

    set pnm1   [polynomial 1.0]
    set pn     [polynomial [list [expr {1.0-$alpha}] -1.0]]

    if { $n == 0 } {return $pnm1}
    if { $n == 1 } {return $pn}

    set degree 1
    while { $degree < $n } {
        set an       [expr {-1.0/($degree+1.0)}]
        set bn       [expr {(2.0*$degree+$alpha+1)/($degree+1.0)}]
        set cn       [expr {($degree+$alpha)/($degree+1.0)}]
        set factor_n [polynomial [list $bn $an]]
        set term_nm1 [multPolyn $pnm1 [expr {-1.0*$cn}]]
        set term_n   [multPolyn $factor_n $pn]
        set pnp1     [addPolyn $term_n $term_nm1]

        set pnm1     $pn
        set pn       $pnp1
        incr degree
    }

    return $pnp1
}

# hermite --
#    Return the nth degree Hermite polynomial
#
# Arguments:
#    n            The degree of the polynomial
# Result:
#    Polynomial definition
#
proc ::math::special::hermite {n} {
    if { ! [string is integer -strict $n] || $n < 0 } {
        return -code error "Degree must be a non-negative integer"
    }

    set pnm1   [polynomial 1.0]
    set pn     [polynomial {0.0 2.0}]

    if { $n == 0 } {return $pnm1}
    if { $n == 1 } {return $pn}

    set degree 1
    while { $degree < $n } {
        set an       2.0
        set bn       0.0
        set cn       [expr {2.0*$degree}]
        set factor_n [polynomial [list $bn $an]]
        set term_n   [multPolyn $factor_n $pn]
        set term_nm1 [multPolyn $pnm1 [expr {-1.0*$cn}]]
        set pnp1     [addPolyn $term_n $term_nm1]

        set pnm1     $pn
        set pn       $pnp1
        incr degree
    }

    return $pnp1
}

# some tests --
#
if { 0 } {
set prec $::tcl_precision
if {![package vsatisfies [package provide Tcl] 8.5]} {
    set ::tcl_precision 17
} else {
    set ::tcl_precision 0
}

puts "Legendre:"
foreach n {0 1 2 3 4} {
    puts [::math::special::legendre $n]
}

puts "Chebyshev:"
foreach n {0 1 2 3 4} {
    puts [::math::special::chebyshev $n]
}

puts "Laguerre (alpha=0):"
foreach n {0 1 2 3 4} {
    puts [::math::special::laguerre 0.0 $n]
}
puts "Laguerre (alpha=1):"
foreach n {0 1 2 3 4} {
    puts [::math::special::laguerre 1.0 $n]
}

puts "Hermite:"
foreach n {0 1 2 3 4} {
    puts [::math::special::hermite $n]
}

set ::tcl_precision $prec
}
