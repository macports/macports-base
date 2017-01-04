# exponential.tcl --
#    Compute exponential integrals (E1, En, Ei, li, Shi, Chi, Si, Ci)
#

namespace eval ::math::special {
    variable pi 3.1415926
    variable gamma 0.57721566490153286
    variable halfpi [expr {$pi/2.0}]

# Euler's digamma function for small integer arguments

    variable psi {
        NaN
        -0.57721566490153286 0.42278433509846713 0.92278433509846713
        1.2561176684318005 1.5061176684318005 1.7061176684318005
        1.8727843350984672 2.0156414779556102 2.1406414779556102
        2.2517525890667214 2.3517525890667215 2.4426616799758123
        2.5259950133091458 2.6029180902322229 2.6743466616607945
        2.7410133283274614 2.8035133283274614 2.8623368577392259
        2.9178924132947812 2.9705239922421498 3.0205239922421496
        3.0681430398611971 3.1135975853157425 3.1570758461853079
        3.1987425128519744 3.2387425128519745 3.2772040513135128
        3.31424108835055 3.3499553740648356 3.3844381326855251
        3.4177714660188583 3.4500295305349873 3.4812795305349873
        3.5115825608380176 3.5409943255438998 3.5695657541153283
        3.597343531893106 3.6243705589201332 3.6506863483938172
        3.6763273740348428
    }
}

# ComputeExponFG --
#    Compute the auxiliary functions f and g
#
# Arguments:
#    x            Parameter of the integral (x>=0)
# Result:
#    Approximate values for f and g
# Note:
#    See Abramowitz and Stegun
#
proc ::math::special::ComputeExponFG {x} {
    set x2 [expr {$x*$x}]
    set fx [expr {($x2*$x2+7.241163*$x2+2.463936)/
                  ($x2*$x2+9.068580*$x2+7.157433)/$x}]
    set gx [expr {($x2*$x2+7.547478*$x2+1.564072)/
                  ($x2*$x2+12.723684*$x2+15.723606)/$x2}]
    list $fx $gx
}


# exponential_Ei --
#    Compute the exponential integral of the second kind, to relative
#    error eps
# Arguments:
#    x       Value of the argument
#    eps     Relative error
# Result:
#    Principal value of the integral exp(x)/x
#    from -infinity to x
#
proc ::math::special::exponential_Ei { x { eps 1.0e-10 } } {
    variable gamma

    if { ![string is double -strict $x] } {
        return -code error "expected a floating point number but found \"$x\""
    }
    if { $x < 0.0 } {
        return [expr { -[exponential_En 1 [expr { - $x }] $eps] }]
    }
    if { $x == 0.0 } {
       set message "Argument to exponential_Ei must not be zero"
       return -code error -errorcode [list ARITH DOMAIN $message] $message
    }
    if { $x >= -log($eps) } {
        # evaluate Ei(x) as an asymptotic series; the series is formally
        # divergent, but the leading terms give the desired value to
        # enough precision.
        set sum 0.
        set term 1.
        set k 1
        while { 1 } {
            set p $term
            set term [expr { $term * ( $k / $x ) }]
            if { $term < $eps } {
                break
            }
            if { $term < $p } {
                set sum [expr { $sum + $term }]
            } else {
                set sum [expr { $sum - $p }]
                break
            }
            incr k
        }
        return [expr { exp($x) * ( 1.0 + $sum ) / $x }]
    } elseif { $x >= 1e-18 } {
        # evaluate Ei(x) as a power series
        set sum 0.
        set fact 1.
        set pow $x
        set n 1
        while { 1 } {
            set fact [expr { $fact * $n }]
            set term [expr { $pow / $n / $fact }]
            set sum [expr { $sum + $term }]
            if { $term < $eps * $sum } break
            set pow [expr { $x * $pow }]
            incr n
        }
        return [expr { $sum + $gamma + log($x) }]
    } else {
        # Ei(x) for small x
        return [expr { log($x) + $gamma }]
    }
}


# exponential_En --
#    Compute the exponential integral of n-th order, to relative error
#    epsilon
#
# Arguments:
#    n            Order of the integral (n>=1, integer)
#    x            Parameter of the integral (x>0)
#    epsilon      Relative error
# Result:
#    Value of En(x) = integral from 0 to x of exp(-x)/x**n
#
proc ::math::special::exponential_En { n x { epsilon 1.0e-10 } } {
    variable psi
    variable gamma
    if { ![string is integer -strict $n] || $n < 0 } {
        return -code error "expected a non-negative integer but found \"$n\""
    }
    if { ![string is double -strict $x] } {
        return -code error "expected a floating point number but found \"$x\""
    }
    if { $n == 0 } {
        if { $x == 0.0 } {
            return -code error "E0(0) is indeterminate"
        }
        return [expr { exp( -$x ) / $x }]
    }
    if { $n == 1 && $x < 0.0 } {
        return [expr {- [exponential_Ei [expr { -$x }] $eps] }]
    }
    if { $x < 0.0 } {
        return -code error "can't evaluate En(x) for negative x"
    }
    if { $x == 0.0 } {
        return [expr { 1.0 / ( $n - 1 ) }]
    }

    if { $x > 1.0 } {
        # evaluate En(x) as a continued fraction
        set b [expr { $x + $n }]
        set c 1.e308
        set d [expr { 1.0 / $b }]
        set h $d
        set i 1
        while { 1 } {
            set a [expr { -$i * ( $n - 1 + $i ) }]
            set b [expr { $b + 2.0 }]
            set d [expr { 1.0 / ( $a * $d + $b ) }]
            set c [expr { $b + $a / $c }]
            set delta [expr { $c * $d }]
            set h [expr { $h * $delta }]
            if { abs( $delta - 1. ) < $epsilon } {
                return [expr { $h * exp(-$x) }]
            }
            incr i
        }
    } else {
        # evaluate En(x) as a series
        if { $n == 1 } {
            set a [expr { -log($x) - $gamma }]
        } else {
            set a [expr { 1.0 / ( $n - 1 ) }]
        }
        set f 1.0
        set i 1
        while { 1 } {
            set f [expr { - $f *  $x / $i }]
            if { $i == $n - 1 } {
                set term [expr { $f * ([lindex $psi $n] - log($x)) }]
            } else {
                set term [expr { $f / ( $n - 1 - $i ) }]
            }
            set a [expr { $a + $term }]
            if { abs($term) < $epsilon * abs($a) } {
                return $a
            }
            incr i
        }
    }
}

# exponential_E1 --
#    Compute the exponential integral
#
# Arguments:
#    x            Parameter of the integral (x>0)
# Result:
#    Value of E1(x) = integral from x to infinity of exp(-x)/x
# Note:
#    This relies on a rational approximation (error ~ 2e-7 (x<1) or 5e-5 (x>1)
#
proc ::math::special::exponential_E1 {x} {
    if { $x <= 0.0 } {
        error "Domain error: x must be positive"
    }

   if { $x < 1.0 } {
      return [expr {-log($x)+((((0.00107857*$x-0.00976004)*$x+0.05519968)*$x-0.24991055)*$x+0.99999193)*$x-0.57721566}]
   } else {
      set xexpe [expr {($x*$x+2.334733*$x+0.250621)/($x*$x+3.330657*$x+1.681534)}]
      return [expr {$xexpe/($x*exp($x))}]
   }
}

# exponential_li --
#    Compute the logarithmic integral
# Arguments:
#    x       Value of the argument
# Result:
#    Value of the integral 1/ln(x) from 0 to x
#
proc ::math::special::exponential_li {x} {
    if { $x < 0 } {
        return -code error "Argument must be positive or zero"
    } else {
        if { $x == 0.0 } {
            return 0.0
        } else {
            return [exponential_Ei [expr {log($x)}]]
        }
    }
}

# exponential_Shi --
#    Compute the hyperbolic sine integral
# Arguments:
#    x       Value of the argument
# Result:
#    Value of the integral sinh(x)/x from 0 to x
#
proc ::math::special::exponential_Shi {x} {
    if { $x < 0 } {
        return -code error "Argument must be positive or zero"
    } else {
        if { $x == 0.0 } {
            return 0.0
        } else {
            proc g {x} {
               return [expr {sinh($x)/$x}]
            }
            return [lindex [::math::calculus::romberg g 0.0 $x] 0]
        }
    }
}

# exponential_Chi --
#    Compute the hyperbolic cosine integral
# Arguments:
#    x       Value of the argument
# Result:
#    Value of the integral (cosh(x)-1)/x from 0 to x
#
proc ::math::special::exponential_Chi {x} {
    variable gamma
    if { $x < 0 } {
        return -code error "Argument must be positive or zero"
    } else {
        if { $x == 0.0 } {
            return 0.0
        } else {
            proc g {x} {
               return [expr {(cosh($x)-1.0)/$x}]
            }
            set integral [lindex [::math::calculus::romberg g 0.0 $x] 0]
            return [expr {$gamma+log($x)+$integral}]
        }
    }
}

# exponential_Si --
#    Compute the sine integral
# Arguments:
#    x       Value of the argument
# Result:
#    Value of the integral sin(x)/x from 0 to x
#
proc ::math::special::exponential_Si {x} {
    variable halfpi
    if { $x < 0 } {
        return -code error "Argument must be positive or zero"
    } else {
        if { $x == 0.0 } {
            return 0.0
        } else {
            if { $x < 1.0 } {
                proc g {x} {
                    return [expr {sin($x)/$x}]
                }
                return [lindex [::math::calculus::romberg g 0.0 $x] 0]
            } else {
                foreach {f g} [ComputeExponFG $x] {break}
                return [expr {$halfpi-$f*cos($x)-$g*sin($x)}]
            }
        }
    }
}

# exponential_Ci --
#    Compute the cosine integral
# Arguments:
#    x       Value of the argument
# Result:
#    Value of the integral (cosh(x)-1)/x from 0 to x
#
proc ::math::special::exponential_Ci {x} {
    variable gamma

    if { $x < 0 } {
        return -code error "Argument must be positive or zero"
    } else {
        if { $x == 0.0 } {
            return 0.0
        } else {
            if { $x < 1.0 } {
                proc g {x} {
                    return [expr {(cos($x)-1.0)/$x}]
                }
                set integral [lindex [::math::calculus::romberg g 0.0 $x] 0]
                return [expr {$gamma+log($x)+$integral}]
            } else {
                foreach {f g} [ComputeExponFG $x] {break}
                return [expr {$f*sin($x)-$g*cos($x)}]
            }
        }
    }
}

# some tests --
#    Reproduce tables 5.1, 5.2 from Abramowitz & Stegun,

if { [info exists ::argv0] && ![string compare $::argv0 [info script]] } {
namespace eval ::math::special {
for { set i 0.01 } { $i < 0.505 } { set i [expr { $i + 0.01 }] } {
    set ei [exponential_Ei $i]
    set e1 [expr { - [exponential_Ei [expr { - $i }]] }]
    puts [format "%9.6f\t%.10g\t%.10g" $i \
              [expr {($ei - log($i) - 0.57721566490153286)/$i} ] \
              [expr {($e1 + log($i) + 0.57721566490153286) / $i }]]
}
puts {}
for { set i 0.5 } { $i < 2.005 } { set i [expr { $i + 0.01 }] } {
    set ei [exponential_Ei $i]
    set e1 [expr { - [exponential_Ei [expr { - $i }]] }]
    puts [format "%9.6f\t%.10g\t%.10g" $i $ei $e1]
}
puts {}
for {} { $i < 10.05 } { set i [expr { $i + 0.1 }] } {
    set ei [exponential_Ei $i]
    set e1 [expr { - [exponential_Ei [expr { - $i }]] }]
    puts [format "%9.6f\t%.10g\t%.10g" $i \
              [expr { $i * exp(-$i) * $ei }] \
              [expr { $i * exp($i) * $e1 }]]

}
puts {}
for {set ooi 0.1} { $ooi > 0.0046 } { set ooi [expr { $ooi - 0.005 }] } {
    set i [expr { 1.0 / $ooi }]
    set ri [expr { round($i) }]
    set ei [exponential_Ei $i]
    set e1 [expr { - [exponential_Ei [expr { - $i }]] }]
    puts [format "%9.6f\t%.10g\t%.10g\t%d" $i \
              [expr { $i * exp(-$i) * $ei }] \
              [expr { $i * exp($i) * $e1 }] \
              $ri]
}
puts {}

# Reproduce table 5.4 from Abramowitz and Stegun

for { set x 0.00 } { $x < 0.505 } { set x [expr { $x + 0.01 }] } {
    set line [format %4.2f $x]
    if { $x == 0.00 } {
        append line { } 1.0000000
    } else {
        append line { } [format %9.7f \
                             [expr { [exponential_En 2 $x] - $x * log($x) }]]
    }
    foreach n { 3 4 10 20 } {
        append line { } [format %9.7f [exponential_En $n $x]]
    }
    puts $line
}
puts {}
for { set x 0.50 } { $x < 2.005 } { set x [expr { $x + 0.01 }] } {
    set line [format %4.2f $x]
    foreach n { 2 3 4 10 20 } {
        append line { } [format %9.7f [exponential_En $n $x]]
    }
    puts $line
}
puts {}

for { set oox 0.5 } { $oox > 0.1025 } { set oox [expr { $oox - 0.05 }] } {
    set line [format %4.2f $oox]
    set x [expr { 1.0 / $oox }]
    set rx [expr { round( $x ) }]
    foreach n { 2 3 4 10 20 } {
        set en [exponential_En $n [expr { 1.0 / $oox }]]
        append line { } [format %9.7f [expr { ( $x + $n ) * exp($x) * $en }]]
    }
    append line { } [format %3d $rx]
    puts $line
}
for { set oox 0.10 } { $oox > 0.005 } { set oox [expr { $oox - 0.01 }] } {
    set line [format %4.2f $oox]
    set x [expr { 1.0 / $oox }]
    set rx [expr { round( $x ) }]
    foreach n { 2 3 4 10 20 } {
        set en [exponential_En $n $x]
        append line { } [format %9.7f [expr { ( $x + $n ) * exp($x) * $en }]]
    }
    append line { } [format %3d $rx]
    puts $line
}
puts {}
catch {exponential_Ei 0.0} result; puts $result
}
}
