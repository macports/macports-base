# elliptic.tcl --
#    Compute elliptic functions and integrals
#
#    Computation of elliptic functions cn, dn and sn
#    adapted from:
#        Michael W. Pashea
#        Numerical computation of elliptic functions
#        Doctor Dobbs' Journal, May 2005
#

# namespace ::math::special
#
namespace eval ::math::special {
    namespace export cn sn dn

    ::math::constants::constants pi

    variable halfpi [expr {$pi/2.0}]
    variable tol

    set tol 1.0e-10
}

# elliptic_K --
#    Compute the complete elliptic integral of the first kind
#
# Arguments:
#    k            Parameter of the integral
# Result:
#    Value of K(k)
# Note:
#    This relies on the arithmetic-geometric mean
#
proc ::math::special::elliptic_K {k} {
    variable halfpi
    if { $k < 0.0 || $k >= 1.0 } {
        error "Domain error: must be between 0 (inclusive) and 1 (not inclusive)"
    }

    if { $k == 0.0 } {
        return $halfpi
    }

    set a 1.0
    set b [expr {sqrt(1.0-$k*$k)}]

    for {set i 0} {$i < 10} {incr i} {
        set anew [expr {($a+$b)/2.0}]
        set bnew [expr {sqrt($a*$b)}]

        set a $anew
        set b $bnew
        #puts "$a $b"
    }

    return [expr {$halfpi/$a}]
}

# elliptic_E --
#    Compute the complete elliptic integral of the second kind
#
# Arguments:
#    k            Parameter of the integral
# Result:
#    Value of E(k)
# Note:
#    This relies on the arithmetic-geometric mean
#
proc ::math::special::elliptic_E {k} {
   variable halfpi
   if { $k < 0.0 || $k >= 1.0 } {
       error "Domain error: must be between 0 (inclusive) and 1 (not inclusive)"
   }

   if { $k == 0.0 } {
       return $halfpi
   }
   if { $k == 1.0 } {
       return 1.0
   }

   set a      1.0
   set b      [expr {sqrt(1.0-$k*$k)}]
   set sumc   [expr {$k*$k/2.0}]
   set factor 0.25

   for {set i 0} {$i < 10} {incr i} {
       set anew   [expr {($a+$b)/2.0}]
       set bnew   [expr {sqrt($a*$b)}]
       set sumc   [expr {$sumc+$factor*($a-$b)*($a-$b)}]
       set factor [expr {$factor*2.0}]

       set a $anew
       set b $bnew
       #puts "$a $b"
   }

   set Kk [expr {$halfpi/$a}]
   return [expr {(1.0-$sumc)*$Kk}]
}

namespace eval ::math::special {
}

# Nextk --
#     Auxiliary function for computing next value of k
#
# Arguments:
#     k           Parameter
# Return value:
#     Next value to be used
#
proc ::math::special::Nextk { k } {
    set ksq [expr {sqrt(1.0-$k*$k)}]
    return [expr {(1.0-$ksq)/(1+$ksq)}]
}

# IterateUK --
#     Auxiliary function to compute the raw value (phi)
#
# Arguments:
#     u           Independent variable
#     k           Parameter
# Return value:
#     phi
#
proc ::math::special::IterateUK { u k } {
    variable tol
    set kvalues {}
    set nmax    1
    while { $k > $tol } {
        set k [Nextk $k]
        set kvalues [concat $k $kvalues]
        set u [expr {$u*2.0/(1.0+$k)}]
        incr nmax
        #puts "$nmax -$u - $k"
    }
    foreach k $kvalues {
        set u [expr {( $u + asin($k*sin($u)) )/2.0}]
    }
    return $u
}

# cn --
#     Compute the elliptic function cn
#
# Arguments:
#     u           Independent variable
#     k           Parameter
# Return value:
#     cn(u,k)
# Note:
#     If k == 1, then the iteration does not stop
#
proc ::math::special::cn { u k } {
    if { $k > 1.0 } {
        return -code error "Parameter out of range - must be <= 1.0"
    }
    if { $k == 1.0 } {
        return [expr {1.0/cosh($u)}]
    } else {
        set u [IterateUK $u $k]
        return [expr {cos($u)}]
    }
}

# sn --
#     Compute the elliptic function sn
#
# Arguments:
#     u           Independent variable
#     k           Parameter
# Return value:
#     sn(u,k)
# Note:
#     If k == 1, then the iteration does not stop
#
proc ::math::special::sn { u k } {
    if { $k > 1.0 } {
        return -code error "Parameter out of range - must be <= 1.0"
    }
    if { $k == 1.0 } {
        return [expr {tanh($u)}]
    } else {
        set u [IterateUK $u $k]
        return [expr {sin($u)}]
    }
}

# dn --
#     Compute the elliptic function sn
#
# Arguments:
#     u           Independent variable
#     k           Parameter
# Return value:
#     dn(u,k)
# Note:
#     If k == 1, then the iteration does not stop
#
proc ::math::special::sn { u k } {
    if { $k > 1.0 } {
        return -code error "Parameter out of range - must be <= 1.0"
    }
    if { $k == 1.0 } {
        return [expr {1.0/cosh($u)}]
    } else {
        set u [IterateUK $u $k]
        return [expr {sqrt(1.0-$k*$k*sin($u))}]
    }
}


# main --
#    Simple tests
#
if { 0 } {
puts "Special cases:"
puts "cos(1):    [::math::special::cn 1.0 0.0] -- [expr {cos(1.0)}]"
puts "1/cosh(1): [::math::special::cn 1.0 0.999] -- [expr {1.0/cosh(1.0)}]"
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
#foreach k {0.0 0.1 0.2 0.4 0.6 0.8 0.9} {
#    puts "$k: [::math::special::elliptic_K $k]"
#}
foreach k2 {0.0 0.1 0.2 0.4 0.6 0.8 0.9} {
    set k [expr {sqrt($k2)}]
    puts "$k2: [::math::special::elliptic_K $k] \
[::math::special::elliptic_E $k]"
}
set ::tcl_precision $prec
}

