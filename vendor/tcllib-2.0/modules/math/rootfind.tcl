# rootfind.tcl --
#     Root-finding procedures:
#     - Bisection
#     - Secant
#     - Brent
#     - Chandrupatla
#
#     TODO: f(root), number of steps, converged or not
#
#     TOMS748? Seems quite complicated
#     Brent in stead of secant - more robust, Chandrupatla is supposed to be faster
#

namespace eval ::math::calculus {}

# root_bisection --
#     Find a root of a function of one variable via bisection
#
# Arguments:
#     f                Procedure implementing the function
#     a                Left point of the interval
#     b                Right point of the interval
#     tol              Tolerance (optional)
#
# Returns:
#     The approximation of the root
#
# Note:
#     The interval [a,b] must enclose an odd number of roots,
#     that is: f(a)*f(b) < 0
#
proc ::math::calculus::root_bisection {f a b {tol 1.0e-7}} {

    if { $tol <= 0.0 } {
        return -code error "The tolerance must be a small positive value"
    }

    set fa [$f $a]
    set fb [$f $b]

    if { ($fa < 0.0 && $fb < 0.0) || ($fa > 0.0 && $fb > 0.0) } {
        return -code error "The given interval does not enclose an odd number of roots: f($a) = $fa, f($b) = $fb"
    }

    set steps    0

    set reduction [expr {min( 2.0e16, abs($b-$a)/$tol )}]
    set maxsteps [expr {int( log($reduction)/log(2.0) )}] ;# Maximum number of halvings that makes sense

    while { $steps < $maxsteps } {
        incr steps

        set c  [expr {($a + $b)/ 2.0}]
        set fc [$f $c]

        if { ($fc <= 0.0 && $fa <= 0.0) || ($fc >= 0.0 && $fa >= 0.0) } {
            set a  $c
            set fa $fc
        } else {
            set b $c
            set fb $fc
        }

        # Special case ...
        if { $fc == 0.0 } {
            return $c
        }
    }

    return $c
}

# root_secant --
#     Find a root of a function of one variable via the secant method
#
# Arguments:
#     f                Procedure implementing the function
#     a                Left point of the interval
#     b                Right point of the interval
#     tol              Tolerance (optional)
#
# Returns:
#     The approximation of the root
#
# Note:
#     The method is not guranteed to converge, but if it does, it does so
#     quicker than linear. The maximum number of steps is derived from the
#     idea that the interval will be roughly halved in length.
#
proc ::math::calculus::root_secant {f a b {tol 1.0e-7}} {

    if { $tol <= 0.0 } {
        return -code error "The tolerance must be a small positive value"
    }

    set fa [$f $a]
    set fb [$f $b]

    if { ($fa < 0.0 && $fb < 0.0) || ($fa > 0.0 && $fb > 0.0) } {
        return -code error "The given interval does not enclose an odd number of roots: f($a) = $fa, f($b) = $fb"
    }

    set steps    0

    set reduction [expr {min( 2.0e16, abs($b-$a)/$tol )}]
    set maxsteps [expr {int( log($reduction)/log(2.0) )}] ;# Maximum number of halvings that makes sense


    while { $steps < $maxsteps } {
        incr steps

        set c  [expr {($a * $fb - $b * $fa) / double($fb - $fa)}]
        set fc [$f $c]

        if { abs($c - $b) <= $tol } {
            break
        }

        set a  $b
        set fa $fb
        set b  $c
        set fb $fc
    }

    return $c
}

# root_chandrupatla --
#     Find a root of a function of one variable via the method by Chandrupatla (variation on Brent's method)
#
# Arguments:
#     f                Procedure implementing the function
#     x0               Left point of the interval
#     x1               Right point of the interval
#     tol              Tolerance (optional)
#
# Returns:
#     The approximation of the root
#
# Note:
#     The method brackets a root, like the bisection method.
#
#     Adopted from www.embeddedrelated.com/showarticle/855.php
#
proc ::math::calculus::root_chandrupatla {f x0 x1 {tol 1.0e-7}} {

    if { $tol <= 0.0 } {
        return -code error "The tolerance must be a small positive value"
    }

    set b $x0
    set a $x1
    set c $x1

    set fa [$f $a]
    set fb [$f $b]
    set fc $fa

    if { ($fa < 0.0 && $fb < 0.0) || ($fa > 0.0 && $fb > 0.0) } {
        return -code error "The given interval does not enclose an odd number of roots: f($a) = $fa, f($b) = $fb"
    }

    set steps 0

    set t 0.5

    set eps_m $tol
    set eps_a [expr {2.0 * $tol}] ;# TODO

    while { 1 } {
        incr steps

        #
        # Get a new estimate of the root via interpolation
        #
        set xt [expr {$a + $t * ($b - $a)}]
        set ft [$f $xt]

        #
        # Update the three points we keep track of
        #
        if { ($ft < 0.0 && $fa < 0.0) || ($ft > 0.0 && $fa > 0.0) } {
            set c  $a
            set fc $fa
        } else {
            set c  $b
            set fc $fb
            set b  $a
            set fb $fa
        }

        set a  $xt
        set fa $ft

        #
        # Determine the point with the smallest function value
        #
        if { abs($fa) < abs($fb) } {
            set xm $a
            set fm $fa
        } else {
            set xm $b
            set fm $fb
        }

        if { $fm == 0.0 } {
            return $xm
        }

        #
        # Critical values xi and phi (decisions on how to proceed)
        #
        set phtol [expr {2.0*$eps_m * abs($xm) + $eps_a}]
        set tlim  [expr {$phtol / abs($b-$c)}]

        if { $tlim > 0.5 } {
            return $xm
        }

        set xi     [expr {($a - $b) / ($c - $b)}]
        set phi    [expr {($fa - $fb) / ($fc - $fb)}]
        set do_iqi [expr {$phi**2 < $xi && (1.0 - $phi)**2 < 1.0 - $xi}]

        if { $do_iqi } {
            #
            # Inverse quadratic interpolation
            #
            set t [expr {$fa / ($fb-$fa) * $fc / ($fb-$fc) +
                         ($c-$a) / ($b-$a) * $fa / ($fc-$a) * $fb / ($fc-$fb)}]
        } else {
            #
            # Bisection
            #
            set t 0.5
        }

        #
        # Limit t between (tlim,1-tlim)
        #
        set t [expr {min( 1.0 -$tlim, max($tlim, $t) )}]
    }
}

# root_brent --
#     Find a root of a function of one variable via Brent's method
#
# Arguments:
#     f                Procedure implementing the function
#     x0               Left point of the interval
#     x1               Right point of the interval
#     tol              Tolerance (optional)
#
# Returns:
#     The approximation of the root
#
# Note:
#     The method brackets a root, like the bisection method but combines it with the secant method and
#     inverse quadratic interpolation.
#
#     Adopted from Wikipedia
#
proc ::math::calculus::root_brent {f x0 x1 {tol 1.0e-7}} {

    if { $tol <= 0.0 } {
        return -code error "The tolerance must be a small positive value"
    }

    set b $x0
    set a $x1
    set c $x1

    #
    # Minimal distance between points at which to calculate the function
    #
    set delta [expr {1.0e-8 * (abs($x0) + abs($x1)) + $tol/3.0}]

    set fa [$f $a]
    set fb [$f $b]

    if { ($fa < 0.0 && $fb < 0.0) || ($fa > 0.0 && $fb > 0.0) } {
        return -code error "The given interval does not enclose an odd number of roots: f($a) = $fa, f($b) = $fb"
    }

    if { abs($fa) < abs($fb) } {
        set tmp $a    ; set tmpf $fa
        set a   $b    ; set fa   $fb
        set b   $tmp  ; set fb   $tmpf
    }

    set c    $a
    set fc   $fa

    set flag 1
    set d    0.0 ;# Dummy for the first iteration step

    set s    $b  ;# Make sure s is defined
    set fs   $fb

    #set step 0

    while { abs($b - $a) > $tol && $fb != 0.0 && $fs != 0.0 } {
        #incr step
        if { $fa != $fc && $fb != $fc } {
            set s [expr { $a * $fb * $fc / (($fa-$fb)*($fa-$fc)) +
                          $b * $fa * $fc / (($fb-$fa)*($fb-$fc)) +
                          $c * $fa * $fb / (($fc-$fa)*($fc-$fb)) }]
        } else {
            set s [expr {$b - $fb * ($b-$a) / ($fb -$fa)}]
        }

        # Check the conditions for the next step
        if { ( ((3.0*$a+$b) / 4.0 - $s) * ($s - $b) < 0.0 ) ||
             ( $flag  && abs($s-$b) >= abs($b-$c)/2.0 )     ||
             ( !$flag && abs($s-$b) >= abs($c-$d)/2.0 )     ||
             ( $flag  && abs($b-$c) <  abs($delta) )        ||
             ( !$flag && abs($c-$d) <  abs($delta) )           } {
            set s    [expr {($a + $b) / 2.0}]
            set flag 1
        } else {
            set flag 0
        }

        set fs [$f $s]
        set d  $c
        set c  $b

        if { $fa * $fs < 0.0 } {
            set b  $s
            set fb $fs
        } else {
            set a  $s
            set fa $fs
        }

        if { abs($a) < abs($fb) } {
            set tmp $a    ; set tmpf $fa
            set a   $b    ; set fa   $fb
            set b   $tmp  ; set fb   $tmpf
        }
    }

    return $s
}
